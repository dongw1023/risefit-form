# RiseFit Form

New iOS app for video-based deadlift and squat form analysis.

The backend lives in `../risefit-api`. This app should treat the backend as an authenticated API:

- request `POST /form-analyses/upload-url`, upload the original video directly to GCS, then call `POST /form-analyses/from-upload`
- poll `GET /form-analyses/{id}`
- play `GET /form-analyses/{id}/video` when analysis completes

The app does not call motion-engine directly. `risefit-api` enqueues Cloud Tasks work and updates the analysis record when the worker output appears.

## MVP User Flow

1. Sign in with the existing RiseFit auth flow.
2. Pick `deadlift` or `squat`.
3. Select a local video from Photos.
4. Upload the original video directly to GCS with the API-signed URL.
5. Show queued/processing/completed/failed state.
6. Display score, grade, event list, and analysed video.

## Current Source Layout

`RiseFitForm/` contains the SwiftUI MVP source:

- `RiseFitFormApp.swift`: app entry point
- `ContentView.swift`: upload, polling, result UI
- `FormAnalysisAPI.swift`: signed GCS upload and polling client
- `FormAnalysisModels.swift`: API response models
- `FormAnalysisViewModel.swift`: selection, upload, and polling state

## Open In Xcode

Open the project file:

```bash
open /Users/dongwang/888888/risefit-form/RiseFitForm.xcodeproj
```

In Xcode, select the `RiseFitForm` scheme and an iPhone Simulator, then press Run.

The app currently points to `http://localhost:8000` in `FormAnalysisAPI.swift`. For the simulator, that reaches your Mac. For a real iPhone, change `baseURL` to your Mac LAN IP or the deployed API URL.
