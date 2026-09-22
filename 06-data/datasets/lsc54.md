# LSC-54 — real format and fit with the template engine

> **What is this?** The format of the public LSC-54 dataset as it actually is, measured before writing
> any converter, and how far it fits the motion-template engine of the app (`motionTemplateStore.ts` +
> `normalize.ts` + DTW in `motionClassifier.ts`).

**Status:** 🟡 Findings v0.1, 2026-09-22 · **Source of the measurements:** `backend/src/domains/ia/training/inspect-lsc54.ts`
over `sample.json`, plus the dataset article.

---

## Citation and licence

> Mora-Zarate, J. E., Garzón-Castro, C. L., & Castellanos Rivillas, J. A. (2025). *LSC-54: A landmark-based
> dataset for Colombian Sign Language.* Data in Brief. https://doi.org/10.1016/j.dib.2025.112145
> Data: Science Data Bank, https://doi.org/10.57760/sciencedb.25639

**Licence: CC BY-NC 4.0.** Non-commercial use only, with attribution. Any template, model or screen
derived from it must keep this citation. The raw files are never committed
(`backend/.gitignore` ignores `src/domains/ia/training/datasets/` and `output/`).

## Files in the repository (version V4)

| File | Size | What it is |
|---|---|---|
| `datos.json` | **55.2 GB** | Full dataset |
| `sample.json` | 271 MB | Small subset (Signer_1, a few signs) so the README scripts run without the full file |
| `README.ipynb` | 10 KB | Visualisation + landmark-extraction notebook (Python) |
| `RawVideos/` | — | Anonymised source videos |

Download URL pattern: `https://china.scidb.cn/download?fileId=<id>`. File ids come from
`POST https://www.scidb.cn/api/gin-sdb-filetree/public/file/childrenFileListByPath`
(`{dataSetId, version: "V4", path: "/V4", lastIndex: 0, pageSize: 100}`).
Measured throughput from Colombia: **~100 KB/s per connection**. The server answers `Range`
requests (`206 Partial Content`).

## Structure

Six nested levels, all keys are strings:

```
Signer_<n> / <category> / <sign> / vid_<n> / rep_<n> / frame_<n> / { r_hand, l_hand, face, pose }
```

| Level | Meaning (per the article, confirmed on the data) |
|---|---|
| `Signer_n` | Participant (22) |
| category | `Cordialidad`, `Colores`, `Numeros`* |
| sign | Spanish name, e.g. `Apoyar` |
| `vid_n` | One original recording (2,850 in total, ~4.2 per sign and signer) |
| `rep_n` | **Augmented copy of that recording.** Measured: `rep_1` = `rep_0` with a constant `+0.1565` shift in `x`; `y` and `z` identical. 45 copies per video in the full file (128,250 total) |
| `frame_n` | Contiguous from `frame_0`; **variable length** (44–45 in the measured samples, 30 FPS) |

\* Category spellings other than `Cordialidad` still have to be read from the full data.

Each part stores its coordinates **by column**, not as a list of points:

```json
"r_hand": { "x": [21 numbers], "y": [21 numbers], "z": [21 numbers] }
```

| Part | Points | Notes |
|---|---|---|
| `r_hand`, `l_hand` | 21 | MediaPipe Hands order (0 = wrist, 9 = middle MCP, …) |
| `pose` | 33 | MediaPipe Pose |
| `face` | 478 | MediaPipe Face Landmarker; **all `null`** when no face was detected |

Coordinates: `x`, `y` normalised to the frame (0,0 top-left, 1,1 bottom-right; `y` can exceed 1),
recorded at **1920 × 1080 (16:9)**. `z` uses the scale of `x`, origin at the wrist (hands) or hip (pose).

### Three kinds of "hand" in a frame

The inspector classifies every hand of every frame:

| Kind | How to recognise it | Origin |
|---|---|---|
| **Real** | 21 numeric points, > 4 distinct positions | MediaPipe Hands detection |
| **Forward-filled** | Same shape as the previous frame, shifted | Article: forward fill + wrist shift when the hand was lost for one frame |
| **Pose filler** | Only **4 distinct points**, repeated to fill the 21 slots | When the hand was lost in this *and* the previous frame, the 21 slots are copied from the pose hand points (wrist, pinky, index, thumb: pose 15/17/19/21 or 16/18/20/22) |

In the first sample (`Signer_1/Cordialidad/Apoyar/vid_0/rep_0`, 45 frames) only frames 13–32 have real
hands; frames 0–12 and 33–44 are pose filler. The article also warns that signers did not start at the
same moment, so the active part of each sample is not aligned.

`r_hand` / `l_hand` were assigned by the authors by proximity to the pose wrists. In the measured sample
`r_hand` matches pose points 15/17/19/21 (MediaPipe's *left* side). Which of the two is the signer's
dominant hand, and whether the video is mirrored with respect to our live camera, is **not settled** and
has to be checked on the camera (step 3d).

## Measured on the full `sample.json` (MD5 verified)

70 samples, **Signer_1 only**, **5 signs**, all `Cordialidad`:

| Sign | Samples (`rep`) | Frames min/mean/max | Real frames r/l (mean) | Moving hand r/l | Two-handed |
|---|---|---|---|---|---|
| Bienvenido | 20 | 45/48/55 | 25.5/26.3 | 0/20 | 20/20 |
| Ayudar | 15 | 43/45.7/48 | 20.7/23.3 | 5/10 | 10/15 |
| Bien | 15 | 40/41.3/44 | 1.3/17.3 | 5/10 | 0/15 |
| Apoyar | 10 | 45/48/51 | 18.5/24 | 5/5 | 10/10 |
| Baño | 10 | 54/64/74 | 2/55.5 | 0/10 | 0/10 |

- Frames per sample: 40–74 (mean 48.4). None of them has 30.
- Hand frames overall: `r_hand` 31 % real / 69 % pose filler; `l_hand` 57 % real / 43 % filler. No `null` hands.
- In one-handed signs (`Bien`, `Baño`) the working hand is **`l_hand`**: that is the label to pick for the
  dominant hand in this data, not `r_hand`.
- 3 of the 5 signs are two-handed most of the time.
- `Bienvenido` and `Baño` are not in the article's sign table: class names must be read from `datos.json`.
- Real-hand ranges: x 0–1, y 0.07–1.09, z −0.97–0.03.

## Fit with the template engine

Target format (`motionTemplateStore.ts`): `{ label, frames: number[16][63] }`, each frame being
`normalizeLandmarks()` of **one hand**: 21 points translated to the wrist and divided by the
wrist→middle-MCP 3D distance. Live, the web provider samples one hand every **120 ms**, keeps a
**2.2 s** window, empties it when a frame has no hand, and resamples to 16 by rounded index.

| Aspect | Fits? | Consequence for the converter / engine |
|---|---|---|
| 21 landmarks, MediaPipe order, x/y/z scales | ✅ | `normalize.ts` applies as is |
| Fixed 30 frames per sample | ❌ (the plan assumed it) | Variable length; trim to the active span before resampling to 16 |
| Pose-filler frames | ❌ | Must be dropped; normalising them yields garbage (4 points, scale from two near-equal points) |
| Temporal alignment | ❌ | Trim per sample; the live 2.2 s window also contains idle frames |
| `rep_n` copies | — | Identical after normalisation: use **`rep_0` only**. Effective samples ≈ 2,850 (~53 per sign) |
| Handedness / mirroring | ⚠️ unknown | Pick the moving hand per sample; test both chiralities in 3d |
| Aspect ratio 16:9 | ⚠️ | Hand shapes are compared in frame-normalised x/y; a 4:3 webcam squeezes x by 25 % relative to the data |
| Hand position, trajectory, second hand, face | ❌ **structural** | `normalize.ts` keeps only the finger shape of one hand. Signs that differ by where the hand is, how it travels or by the other hand look the same to the engine |
| Access to the data | ❌ | `sample.json` does not cover the 54 signs; `datos.json` is 55 GB at ~100 KB/s (~6 days). Range requests allow fetching only `rep_0` of each video (1/45 of the bytes) |

**Conclusion:** the per-frame hand data is compatible with the engine, but the dataset cannot be
"just converted": the converter must drop pose filler, trim, deduplicate augmentation and choose the
hand, and the engine by design cannot separate signs that differ by trajectory or location. The 20
words must be chosen by measuring separability with the same DTW, on real data, before touching the app.

## First conversion run — two findings

Measured on the 14 `rep_0` samples of `sample.json` (one signer, 5 signs), converted with
`convert-lsc54-to-templates.ts` and compared with the app's own DTW. Nearest-neighbour,
leaving each sample out:

**1. The dominant hand must be chosen per class, not per sample.** `r_hand`/`l_hand` are assigned
by the authors from pose proximity, and which one holds more real frames flips between samples of
the same sign. Mixing them leaves mirrored sequences that DTW reads as different signs:

| Hand choice | Nearest-neighbour hits | Mean DTW, same sign |
|---|---|---|
| Per sample (most real frames) | 11/14 | 4.67 |
| **Per class, by majority** | **12/14** | **3.61** |

**2. The app's acceptance threshold does not fit dataset templates.** DTW distances between two
recordings of the same sign run **1.85–4.7** (mean 3.6), while `MAX_GESTURE_DISTANCE` is **1.1**
and confidence ≥ 0.7 needs ≤ 0.857. **The app would reject every dataset template and never show a
word**, even when the nearest one is correct.

The ranking still carries signal — same sign 3.6 vs different sign 6.4 on average — so the issue is
the absolute scale, not the features. The threshold was tuned for templates recorded in the app by
the same person on the same camera; templates from other people on another camera sit much further
away. This is the same knob as step 3f of the plan, but it turns out to be a blocker, not a polish
item: it has to be re-tuned from the cross-signer measurement (`measure-lsc54-separability.ts`),
choosing a value that accepts correct matches without letting wrong ones through.

Both numbers come from a single signer, which is the optimistic case. Cross-signer distances are
expected to be larger.
