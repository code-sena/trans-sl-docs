# Model input format — the contract between training and the app

> **What is this?** The exact shape of what the recogniser eats: which landmarks, in which order,
> normalised how, over how many frames. Every extractor (LSC-54, LSC50, LSC70W) must produce this,
> and the app must build the same thing at runtime from the camera. If they drift, the model sees
> something it was never trained on and the accuracy measured offline means nothing.

**Status:** 🟡 v1, 2026-09-24 · Target delivery 2026-10-08

---

## 1. Decisions this format rests on

| Decision | Choice | Why |
|---|---|---|
| Landmark source | MediaPipe Tasks **HandLandmarker** (2 hands) + **PoseLandmarker** | The app already runs HandLandmarker; pose is added for the shoulder frame of reference |
| Frame of reference | Shoulder centre, scaled by shoulder distance | Keeps *where* the hand is relative to the body, which wrist-relative features throw away |
| Sequence length | **30 frames @ 15 fps** (2.0 s) | Long enough for the slowest LSC-54 signs measured (≈2.5 s active span) without a large model |
| Features per frame | **128** | 2 hands × 21 points × (x, y, z) = 126, plus one presence flag per hand |
| Model family | GRU or Conv1D | LSTM converts to TFLite with more friction |
| Split | By signer | Same person in train and test inflates accuracy |

**Why not wrist-relative, as the app does today.** The current engine centres each hand on its own
wrist, so two signs made with the same handshape at different heights are identical to it. Measured
on LSC-54: *naranja* was read as *blanco* in 5 of 7 attempts, and *bien* sat closer to another sign
than to itself. Shoulder normalisation is what removes that blind spot.

## 2. Landmarks kept

| Source | Points | Index range in the feature vector |
|---|---|---|
| Right hand (signer's own right) | 21 | 0–62 |
| Left hand | 21 | 63–125 |
| Presence flags (right, left) | 2 | 126–127 |

Hand points follow the MediaPipe order (0 wrist, 1–4 thumb, 5–8 index, 9–12 middle, 13–16 ring,
17–20 pinky). Pose points are **not** part of the vector: shoulders only define the frame of
reference, so after normalisation they are constants and carry no information.

**Hand assignment.** MediaPipe returns a handedness label per detection. Its convention assumes a
mirrored (selfie) image, so the label is taken as-is at runtime and the extractor must apply the
same rule to the training videos, which are **not** mirrored. The extractor therefore assigns hands
by proximity to the pose wrists (`left_wrist` = 15, `right_wrist` = 16), the same rule the LSC-54
authors used, and never by MediaPipe's label.

## 3. Normalisation, step by step

For every frame, with `Ls` = left shoulder (pose 11), `Rs` = right shoulder (pose 12):

```
centre = (Ls + Rs) / 2                      # 2D, image coordinates
scale  = ||Ls - Rs||                        # shoulder distance in image units
x' = (x - centre.x) / scale
y' = (y - centre.y) / scale
z' =  z / scale                             # z is already wrist-relative, only rescaled
```

- `x`, `y`, `z` are MediaPipe's **image-normalised** coordinates (0–1 across width/height), not the
  world landmarks. This is what LSC-54 stores, so both datasets stay comparable.
- `z` keeps MediaPipe's own meaning: depth relative to the wrist, on the scale of `x`. It is
  rescaled but never translated.
- If `scale` is 0 or the shoulders are missing, the frame is dropped.

A hand that was not detected contributes 63 zeros and a presence flag of 0. **Zeros are the
"absent" value precisely because the origin is the shoulder centre, which no real hand occupies.**

## 4. Sequence assembly

1. Extract landmarks for every frame of the clip.
2. Fill gaps as LSC-54 does: forward-fill a hand missing in a frame from the previous frame; if it
   was missing in the previous frame too, leave zeros and flag 0.
3. **Trim to the active span.** Keep from the first to the last frame whose wrist speed exceeds
   0.02 shoulder widths per frame, with a 2-frame margin on each side.
4. Resample to exactly **30 frames**: linear interpolation on the coordinates, nearest neighbour on
   the two presence flags, which are 0 or 1 and have no meaningful middle value.

**Why the trim matters.** LSC50 clips run 2.1 s to 5.6 s (mean 2.7 s) and open and close with the
signer standing still. The app never sees that: it classifies a 2.0 s window while the person is
moving. Training on the raw clip teaches the model an idle stretch it will never get. After
trimming, the measured mean drops to 2.2 s, which fits the runtime window.

**Sampling rate parity.** Training resamples to 15 fps. The app must feed the model at the same
rate: a 2.0 s window sampled every ~67 ms. The current engine samples every 120 ms (8.3 fps), so
this changes when pose is added.

## 5. On-disk format

One JSON per clip, or one JSONL per dataset split:

```json
{
  "dataset": "lsc50",
  "signer": "0002",
  "gloss": "gracias",
  "source_clip": "0007_0002_0001.avi",
  "fps_original": 30,
  "frames": [[128 numbers], [128 numbers], "... 30 in total"],
  "hands_present": [30, 28]
}
```

`gloss` is the unified label (see `labels.json`), not the dataset's own class name.

## 6. What each dataset needs

| Dataset | State | Work needed |
|---|---|---|
| **LSC-54** | Landmarks already extracted by its authors, image-normalised x/y/z, 30 fps | Re-normalise to the shoulder frame using its `pose` block; no video processing |
| **LSC50** | 1000 RGB clips (`COLOR_BODY`) at **24 fps**, named `<sign>_<signer>_<rep>.avi`, 5 signers × 50 signs × 4 takes | Full extraction with the pipeline in this document |
| **LSC70W** | JPG sequences, 6 frames each | 6 → 30 frames is a 5x stretch; first candidate to cut |

LSC-54 already carries a `pose` block with the 33 MediaPipe pose points, so its shoulders are
available without touching a single video. That is what makes the two datasets mergeable.

## 7. From clips to a training set

`build_dataset.py` turns the per-dataset `.jsonl` files into one `.npz`:

1. **Unified labels.** `labels.json` maps each dataset's own class to a gloss. LSC-54 names its
   signs in Spanish and fills itself in; LSC50 numbers them `0000`–`0049` and **its publication
   does not say which word each number is**, so those stay `null` and are excluded until filled.
2. **Split by signer, per dataset.** 20 % of the signers to validation, 20 % to test, the rest to
   training. Splitting inside each dataset keeps every split representative of all sources.
3. **Augmentation, training split only.** Four variants per clip:
   - **mirror** — swap the two hands and negate `x`; with the origin at the shoulder centre this is
     exactly the sign made with the other hand, which is how a left-handed signer would do it;
   - **time warp ×1.25 and ×0.8** — the same sign performed slower or faster;
   - **jitter** — scale 0.9–1.1 and shift ±0.05, standing for a different distance to the camera.
     Frames where a hand was absent stay at zero so augmentation never invents a hand.
4. **`.npz` output** with `X_train/val/test`, `y_*`, `signers_*` and the gloss list.

The signer lists are written into the file so that a leak can be checked, not just assumed.

## 8. Training protocol

The model is **Conv1D + bidirectional GRU**, about 200k parameters: two Conv1D blocks summarise
local movement, the GRU reads the whole sequence. GRU rather than LSTM because it converts to
TFLite with less friction, and small because it has to run in a phone browser with the same latency
as on a desktop.

Two models are trained every time, and the second is only worth keeping if it beats the first:

| Model | Data | Purpose |
|---|---|---|
| base | LSC-54 only | the reference |
| unified | all sources | what ships, if it wins |

Guards built into the pipeline, each one there because it silently corrupts results otherwise:

- **Classes with fewer than 2 signers are dropped.** A sign recorded by a single person lands
  entirely in one split: never learned, or never evaluated. With the partial LSC-54 download
  (192 of ~2850 clips) this removes 19 of 28 glosses — a symptom of the missing data, not of the
  rule.
- **A warning is printed for any gloss with no training or no test samples.**
- **Class weights** compensate uneven sign counts.
- **Accuracy is reported per source** on the test split: if the unified model scores far better on
  one dataset than the other, it is keying on the dataset rather than on the sign.

## 9. The runtime side

The app builds the same vector from the camera in
`frontend/src/feature/Translation/services/vision/featureBuilder.ts`, a line-by-line counterpart of
`extract_landmarks.py`. It runs **HandLandmarker (2 hands) and PoseLandmarker** on the video
element every 67 ms, keeps the last 2 s, resamples to 30 frames and feeds the TensorFlow.js model.

**Parity is checked, not assumed.** The same synthetic frame (33 pose points, two hands) was pushed
through both implementations: largest difference **1.19e-07**, which is float32 rounding. Re-run
that check whenever either file changes — a silent drift here invalidates every offline metric.

Which engine answers is decided when the camera starts:

| Condition | Engine |
|---|---|
| `/models/lsc/model.json` is served | the trained model |
| it is not | Google's 7-gesture recogniser, as before |

That fallback is what keeps the app working while the model is being trained, and it is also the
answer to the collision the 7 gestures caused: `Thumb_Up` was mapped to *Bien*, so *apoyar* and
*ayudar* — both made with the thumb up in LSC — always came out as *Bien*. Once the model is in
place, the generic gestures are gone.

## 10. Export: one model, two runtimes

The trained `.keras` file cannot be shipped as-is. It is converted twice — TensorFlow.js for the
browser, TFLite for the native app — and both conversions come from **the same SavedModel**, so
there is one point where the two runtimes could diverge instead of two.

### The GRU has to be unrolled first

Trained on a GPU, Keras compiles the bidirectional GRU down to NVIDIA's cuDNN kernel. The exported
graph then contains `CudnnRNNV3` and `ReverseSequence`, and the TensorFlow.js converter stops:

    ValueError: Unsupported Ops in the model before optimization
    ReverseSequence, CudnnRNNV3

The fix is `unroll=True` on the GRU: the recurrent steps are written out one by one instead of
being left as a loop. After the two pooling layers the sequence is 7 steps long, so unrolling costs
almost nothing, and the result is built only from operations both runtimes support — it also
removes the need for `SELECT_TF_OPS` on the TFLite side, which would have dragged a large part of
TensorFlow into the mobile app.

**Unrolling does not touch the weights.** The trained model is rebuilt with the same architecture
and `set_weights`, so no retraining and no loss of accuracy. `export_model.py` verifies this rather
than assuming it.

### Equivalence gates

`backend/src/domains/ia/training/extraction/export_model.py` runs the test split through each
artefact and compares against the trained model. Two gates, both on real sequences — random noise
does not exercise the same paths through the network:

| Comparison | Requirement |
|---|---|
| unrolled vs. trained | identical top-1, difference ≤ 1e-6 |
| TFLite vs. trained | identical top-1, difference ≤ 1e-4 |

Neither artefact is published if a gate fails. Quantisation is left off for the same reason: it
saves around 200 KB and costs the guarantee that web and mobile agree.

### Where the files land

`export/tfjs/` (`model.json`, the `.bin` shards, `glosas.json`) goes to `frontend/public/models/lsc/`.
Expo serves `public/` at the site root, which is where `WORD_MODEL_URL` points. The `.tflite` is for
the native app and is not served over the web.

## 11. Risks recorded against this format

- **The app has to change.** It runs HandLandmarker only; PoseLandmarker has to be added, at a cost
  in CPU per frame, and the sampling rate has to go from 8.3 to 15 fps.
- **Parity between web and device.** ~~Same model exported twice (TFJS and TFLite) is not the
  same binary.~~ Addressed in section 10: both come from one SavedModel and the check is enforced
  by `export_model.py` before anything is published.
- **LSC-54 download is throttled** by its host to ~70 B/s after ~2 GB, so the remaining samples have
  to be pulled from Colab, not from a developer machine.
