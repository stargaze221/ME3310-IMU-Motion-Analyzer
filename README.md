# ME 3310 — IMU Motion Analyzer (Week 11–12)

> **Status: v0.2 beta.** The instructor has run `ME3310_selftest` successfully and imported six real PocketLab forward/backward walking recordings into the GUI (October 31, 2026). The latest output-folder and figure-export changes have **not yet** been rerun in MATLAB; validate them before classroom distribution.

Related lecture demonstrations: https://github.com/stargaze221/ME3310-Motion-Classification

**Purpose:** Convert *actual* PocketLab Voyager MAT recordings of Target and Confusing Motion to 16-dimensional trial feature vectors, then compare 2D/4D/8D/12D/16D **linear nearest-centroid classifiers**. The MATLAB GUI supplies the arithmetic and plots; students supply the measurement design, feature rationale, ranking, and engineering judgment.

## Recommended measurement settings

Recommended **initial**, not compulsory, acquisition settings:

| Item | Starting choice | Notes |
|---|---|---|
| Sample rate | 20 Hz, if supported by the driver | Verify from `t` in each saved MAT. Nyquist = 10 Hz. |
| Window length | 3.0 seconds | 60 samples at 20 Hz; follows the Week 11 lecture example. |
| Hop | 0.5 seconds | 10 samples at 20 Hz; overlapping windows are correlated. |
| Recording length | 10–15 seconds per original trial | 10 s contains 15 complete 3-s windows at 0.5-s hop. |
| Original recordings | 3 Target + 3 Confusing | Train 2 per class; reserve 1 per class for a *preliminary* holdout. |
| Channels | 3-axis acceleration + 3-axis gyro | Both must be present in each MAT file. |

**Important physical caveat:** If the chosen target is a brief event (e.g., one sit-to-stand transition), recording 15 seconds including prolonged rest may drown out the event in trial-average window features. For the first test, keep the motion content and trial duration comparable in both classes, or record repeated occurrences at controlled timing. A future tool version could provide per-trial event cropping; v1 intentionally does not auto-identify ground truth.

Frequency-domain details: at 20 Hz, Nyquist is 10 Hz and a 3-s window resolves variations only at roughly 0.33-Hz scale, even though FFT zero padding produces a visually denser PSD curve. The existing USC-HAD **100-Hz** example has 12–20 and 20–40 Hz features that are **not measurable at 20 Hz**. This tool uses an explicitly *adapted* PocketLab 16-feature set. Frequencies close to Nyquist, and especially narrow low-frequency bands, need cautious interpretation. Do not compare numeric Fisher scores across different acquisition protocols.

## File organization and optional one-time cleanup

The program source files stay in the repository root. Synthetic test data and model exports now default to the **ignored** `results/` tree:

```text
ME3310-IMU-Motion-Analyzer/
  ME3310_IMU_Analyzer.m
  ME3310_IMU_Core.m
  ME3310_export_bundle.m
  ME3310_generate_demo.m
  ME3310_selftest.m
  ME3310_organize_existing.m
  README.md
  .gitignore
  results/                                # ignored by Git
    DEMO_SYNTHETIC_NOT_EXPERIMENTAL_DATA/
    Week11_Target_vs_Confusing/
      ME3310_Week11_Model.mat
      ME3310_Week11_Model_metadata.txt
      ME3310_Week11_Model_trial_features.csv
      ME3310_Week11_Model_trial_predictions.csv
      ME3310_Week11_Model_feature_view.png
      ME3310_Week11_Model_accuracy_comparison.png
      ME3310_Week11_Model_source_MAT/
    Week12_Target_vs_Confusing/
```

Use **Experiment Notes** to enter explicit motion names before exporting if you want a more descriptive folder than `Target_vs_Confusing`. The Save dialog allows choosing another destination, but the recommended default is under `results/`.

If you already exported to the **repository root** with an older version, run this optional one-time migration:

```matlab
cd(fullfile(getenv('USERPROFILE'),'Documents','MATLAB','ME3310-IMU-Motion-Analyzer'))
ME3310_organize_existing
```

It relocates known `ME3310_Week11_Model*` / `ME3310_Week12_Validation*` outputs into `results/Legacy_Week11_Model/` or `results/Legacy_Week12_Validation/`, along with an old synthetic demo folder if the new location is not occupied. It **never overwrites** existing destinations. It does **not** move original data stored in your separate PocketLab driver repository. Legacy metadata and model files retain historical absolute paths; if you need a newly self-consistent archive, re-export from the GUI after running the updated code.

**Number of trials:** There is no fixed upper count of imported MAT recordings. At least two **training trials per class** and one **holdout trial per class** are needed. By default, the third and subsequent recording of each class is labeled Holdout, and students may modify those roles before fitting. One original recording (irrespective of sliding windows) counts as one trial. Available memory and plot/table responsiveness set practical limits.

**Safety/accuracy:** Do not globally disable MATLAB warnings. Known unit labels are informational; invalid sensor channels, mismatched units, sampling-rate inconsistency, and reused Week 11 paths on Week 12 remain errors. If PNG export fails in a MATLAB version, that failure is recorded without aborting model/metadata/CSV exports.

## Files

- `ME3310_IMU_Analyzer.m` — interactive MATLAB GUI.
- `ME3310_IMU_Core.m` — measurement validation, 16 features, Fisher scores, classifiers, predictions, and performance tables.
- `ME3310_export_bundle.m` — human-readable metadata TXT, ML model MAT, feature/prediction CSV, and archived original MAT recordings.
- `ME3310_generate_demo.m` — optional **synthetic** `.mat` files to test GUI import, distinct from experimental evidence.
- `ME3310_selftest.m` — MATLAB unit/smoke test on synthetic data (must be run in MATLAB).
- `ME3310_organize_existing.m` — optional one-time cleanup of older exports from the repository root, without deleting or overwriting student data.

## Quick import of PocketLab live recordings (no conversion)

1. Capture 6-axis Acceleration + Gyroscope data with the PocketLab driver; files such as `fwd_pocketlab_live_20261031_085500_live.mat` are supported directly.
2. From the Analyzer checkout in MATLAB run:

```matlab
repo = gitrepo; pull(repo); % run from the Analyzer's repository folder
clear ME3310_IMU_Analyzer ME3310_IMU_Core ME3310_export_bundle ME3310_selftest
ME3310_selftest
ME3310_IMU_Analyzer
```

3. Click **Import TARGET MAT** and select the three forward-walking MAT files together. Click **Import CONFUSING MAT** and select the three backward-walking files. The labels come from which button you press, never from filename prefixes.
4. Mark one original recording per class **Holdout** before reviewing its results; use the remaining recordings for exploratory training. The holdout of one per class gives only descriptive preliminary results.
5. For the 20-Hz PocketLab profile, start with 3.0-s windows and 0.5-s hops. Check the dashboard and export results.

For a quick format inspection of a saved recording (do not need to move files):

```matlab
S=load('fwd_pocketlab_live_20261031_085500_live.mat');
fieldnames(S.data)
size(S.data.acceleration)
size(S.data.gyroscope)
numel(S.t)
```

## Run

1. Extract these `.m` files into **one folder**. In MATLAB, change Current Folder to that directory (or add it to the path).
2. Optionally run `ME3310_generate_demo` and `ME3310_selftest` to check the software before connecting PocketLab. Synthetic results are not project evidence.
3. Run `ME3310_IMU_Analyzer`.
4. Use **Experiment Notes** to record your selected Target/Confusing definitions, sensor placement, ground-truth method, measurement conditions, feature rationale and proposed next experiment. Import MAT files separately with **Import TARGET MAT** and **Import CONFUSING MAT**. Labels are explicit, **not** inferred from file names.
5. Examine and, if necessary, edit the trial's **Role** column (Train/Holdout). Reserve *whole original recordings*, not overlapping analysis windows.
6. Choose feature profile and the common window/hop. Optionally click **Rank by Fisher (train)** before fitting; this does not use the held-out trials. Click **Fit + Eval (Week 11)**. Each MAT file contributes one 16D feature vector, formed by averaging feature values over its overlapping windows.
7. Before fitting and revealing the holdout, inspect **Fisher scores (training only)** and move individual features up/down to choose the ranked 16 features. The GUI prevents feature re-ranking once the holdout evaluation has been displayed. A changed model requires fresh independent evaluation data.
8. Compare **2D, 4D, 8D, 12D, 16D** accuracy. The 2D pane visualizes a linear decision boundary. The other dimensions use the identical class-centroid linear decision rule. Training and preliminary independent-trial results are shown separately.
9. Click **Export ML + Metadata**. By default, the save dialog opens inside `results/Week11_Target_vs_Confusing/` (or a motion-specific name if Experiment Notes are provided). The export includes the model/analysis MAT, `*_metadata.txt`, CSV tables, a feature-view PNG and an accuracy-comparison PNG (if supported by MATLAB), and copies of the original MAT recordings. If graph exporting fails, the issue is recorded in metadata and the GUI status rather than repeatedly printed as a warning stack.
10. In Week 12, click **Load Saved Models**, then import **NEW** independently recorded Target/Confusing trials. Click **Evaluate NEW (Week 12)**. The feature ranking, normalization parameters, linear coefficients, and acquisition protocol remain frozen. Save Week 12 results separately.

## Expected input MAT schema

**Both source formats are supported directly. No manual conversion is needed.**

**Format A — native PocketLab Voyager 2 Live/decoded output** (including `*_live.mat`):

```matlab
t                   % N x 1 nominal time, seconds
data.acceleration   % N x 3, acceleration X/Y/Z
data.gyroscope      % N x 3, angular velocity X/Y/Z
info                % optional driver metadata
```

The original PocketLab file is imported directly into the Analyzer. The driver uses nominal timestamps rather than independently verified sensor hardware times. Sensor labels are taken from `info.Sensors` / `info.Units` when available: acceleration is validated in `g`, while gyroscope units may be `native` (not yet independently verified). The GUI stores unit labels in the trial audit and exported metadata without repeatedly warning about known native units. Inconsistent unit labels across different trials still cause an error.

**Format B — standardized course trial** (same structure as the existing `examples/Student_IMU/load_student_trial.m` convention):

```matlab
t         % N x 1 timestamps, elapsed seconds, strictly increasing
accel     % N x 3 acceleration (X/Y/Z)
gyro      % N x 3 angular rate (X/Y/Z)
meta      % OPTIONAL struct, e.g. meta.Units.accel and meta.Units.gyro
```

All axes must share the same timestamps. `t` is in **seconds**. If a MAT file is missing either acceleration or gyroscope, the Analyzer reports an error rather than replacing missing data. No missing channels are fabricated. A small amount of timestamp jitter is **explicitly interpolated** to an evenly spaced grid for PSD if no individual interval exceeds 1.5× the median interval; larger gaps cause an error. The tool does **not** silently convert unspecified units: verify the same acceleration/gyro units in every trial and between weeks.

## The 16 features

The first 8 match the established 100-Hz lesson's *feature definitions* (when input units are g and degrees/s):

1. Acceleration magnitude STD
2. Acceleration-magnitude dynamic PSD power, 0.8–3.0 Hz
3–5. Gyroscope X/Y/Z RMS
6–8. Gyroscope X/Y/Z mean

**Adapted PocketLab 20-Hz profile:**

9. Accel-magnitude PSD 0.3–0.8 Hz
10. Accel-magnitude PSD 0.8–1.5 Hz
11. Accel-magnitude PSD 1.5–3.0 Hz
12. Accel-magnitude PSD 3.0–5.0 Hz
13. Accel-magnitude PSD 5.0–8.0 Hz
14. Acceleration-magnitude RMS
15. Gyroscope-magnitude RMS
16. Acceleration-magnitude range (max−min)

**Original USC-HAD 100-Hz profile:** first 8 as above, then PSD 0.3–0.8, 0.8–1.5, 1.5–3, 3–5, 5–8, 8–12, 12–20, 20–40 Hz. The 100-Hz option requires sampling above 80 Hz; the 20-Hz option requires sampling above 16 Hz. They are *different feature sets*: models must not be used across profiles.

PSD estimates use a 2-s Hamming-window Welch estimate with 50% overlap inside each analysis window, and the one-sided PSD is integrated over each band. This mirrors the class demonstration while avoiding toolbox dependencies. Bands as narrow as 0.3–0.8 Hz are weakly resolved by a 2-s Welch segment; avoid strong claims from these alone.

## Linear classifier and Fisher

For each selected dimension `d`, training-only features are standardized with stored development-set means and standard deviations. The difference of the standardized Target and Confusing class centroids defines a linear decision score. A score ≥ 0 predicts Target. The two class centroids determine the midpoint boundary. No SVM, LDA covariance inverse, or Statistics toolbox is required.

Univariate Fisher scores use `(mean_Target - mean_Confusing)^2 / (var_Target + var_Confusing)` on **independent TRAIN trials**. The projected multivariate Fisher shown beside each dimension is likewise computed on **TRAIN predictions**; it is an *in-sample descriptive* separation, not independent accuracy. With only two training trials per class, Fisher ranking is extremely unstable. Undefined scores are shown as undefined, not infinity.

## Experimental limitations

- Six independent recordings provide **very little** information about generalization; preliminary held-out accuracy is limited to two trials and changes in 50-percentage-point increments. Report raw error counts.
- Different classifier dimensions are **nested prefixes of one student ranking**. This isolates a controlled dimension comparison (not a search over all feature subsets).
- A feature that wins when repeatedly re-checking held-out data has effectively used that data for selection; these repeated checks compromise the independence claim.
- In Week 12, evaluate the **unchanged** Week 11 model on new independent trials before changing any feature, settings, or sensor placement. Any revised detector must be evaluated on **further** independent trials.
- Overlapping windows are correlated and are never counted as independent repetitions.
- If the window contains mostly rest rather than the event, the analysis can be irrelevant despite a correct numerical output.

## Verification status

This release was reviewed against the existing GitHub MAT loader and USC-HAD feature definitions and statically checked for internal consistency. **MATLAB is not installed in this environment; these files have not been executed in MATLAB against the actual PocketLab driver output.** Run `ME3310_selftest` in MATLAB before the first real-data experiment; then test with actual measured `.mat` files. If real saved files differ from the documented schema, the loader may need a small adaptation.

## New: Metadata TXT and complete reproducibility export

The **Export ML + Metadata** button uses the chosen `*.mat` filename as a shared base name and writes:

- `<base>_metadata.txt` — human-readable experiment setup, every measured trial and split identity, sample rate/duration/windows/units, student-entered experimental notes and ground truth, definitions of all 16 features, Fisher scores, student ranking, linear classifier parameters (training means/scales/weights/intercepts), and dimension-by-dimension results.
- `<base>.mat` — MATLAB `modelBundle` for exact frozen classifier reuse and `analysis` for trial-level numerical results.
- `<base>_trial_features.csv`, `<base>_trial_manifest.csv`, `<base>_trial_predictions.csv` — shareable tables; no MATLAB required to read them.
- `<base>_training_comparison.csv`, `<base>_independent_comparison.csv`, and `<base>_fisher_features.csv` (when available).
- `<base>_dashboard.png` — screenshot of the GUI charts.
- `<base>_source_MAT/` — copies of original MAT recordings with distinct trial IDs prepended to filenames.

**Why multiple formats?** A TXT file documents ML choices and parameter values but cannot faithfully replace the original raw time series and numeric MATLAB model. Keep the companion MAT and CSV files for reproducibility. Export does not automatically write a lab report or make engineering conclusions.