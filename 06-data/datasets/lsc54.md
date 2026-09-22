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
