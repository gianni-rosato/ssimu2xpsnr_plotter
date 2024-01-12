# SSIMULACRA2 + XPSNR Plotter

This script, written in Bash, automates encoding video with x264, x265, SVT-AV1, or VVenC at different CRF values and measuring perceptual quality with the two most useful visual fidelity metrics for video: XPSNR and SSIMULACRA2. Results are output to a user-specified file.

## Usage

```
./ssimu2+xpsnr_plotter.sh [input.y4m] [output.csv] [x264|x265|svt|vvenc] [q_begin] [q_end] [q_increment] [preset]
```

- `input.y4m` - Input video file in YUV4MPEG2 (.y4m) format\*
- `output.csv` - Output CSV file path to write results  
- `[x264|x265|svt|vvenc]` - Encoder to use (x264, x265, or SVT-AV1)
- `[q_begin]` - Starting CRF value
- `[q_end]` - Ending CRF value 
- `[q_increment]` - Increment between CRF values
- `[preset]` - Encoder preset (slower, fast, etc. for x26*, 1, 2, 3 .. 13 for SVT-AV1) 

## Output

The output CSV contains the following columns:

- `q` - CRF value
- `bitrate` - Bitrate
- `xpsnr` - Weighted XPSNR - ( Y_XPSNR \* 4 + U_XPSNR + V_XPSNR ) to emphasize luma without ignoring chroma\*\*
- `ssimu2` - Average SSIMULACRA2
- `real` - Wall clock encoding time
- `sys` - System CPU time used
- `usr` - User CPU time used

## Dependencies

The script requires the following dependencies:

- FFmpeg
- ssimulacra2_rs 
- bc
- x264
- x265
- SVT-AV1
- vvencapp
- ffmpeg_xpsnr (build FFmpeg from source & rename the binary to `ffmpeg_xpsnr`, then copy to `/usr/local/bin` or wherever you'd prefer. [FFmpeg 6.0 XPSNR Plugin](https://github.com/gianni-rosato/xpsnr)).
- ffmpeg_vvc (build FFmpeg from source & rename the binary to `ffmpeg_vvc`. Look up "VVCEasy").
- ffprobe_vvc

## Examples

```bash
./ssimu2+xpsnr_plotter.sh input.y4m x265_slow.csv x265 20 50 5 slower
```

This will encode `video.y4m` with x265 using CRF values 20, 25, 30, 35, 40, 45, & 50 using the `slower` preset, and write quality metrics to `results.csv`.

Some more examples of usage:

```bash
# x264 "ultrafast" preset, high quality CRFs 
./ssimu+xpsnr_plotter.sh video.y4m x264_fast.csv x264 15 35 5 ultrafast

# x265 "medium" preset, wide CRF range
./ssimu+xpsnr_plotter_plotter.sh video.y4m x265_medium.csv x265 5 50 5 medium 

# SVT-AV1 preset 4 (pretty slow), low bitrate target
./ssimu+xpsnr_plotter.sh video.y4m svt_slower.csv svt 40 50 2 4

# x264 "slower" preset, tiny CRF increments
./ssimu+xpsnr_plotter.sh video.y4m x264_slow.csv x264 30 45 1 slower

# x265 "faster" preset, high CRFs
./ssimu+xpsnr_plotter.sh video.y4m x265_fast.csv x265 45 60 5 faster
```

Here's an example of the script's output, run with `./ssimu+xpsnr_plotter.sh foodmarket.y4m x265_slow.csv x265 14 28 2 slow`:

```csv
q bitrate xpsnr ssimu2 real sys usr
14 56840686 43.40156666 82.42236859 38.01 1.03 615.27
16 40302489 42.34751666 78.98464845 36.05 0.85 553.45
18 27622312 41.42185000 75.06703199 31.61 0.89 476.73
20 18404361 40.61101666 70.50155427 28.18 0.89 406.78
22 12370702 39.88436666 65.20823910 24.94 0.86 348.22
24 8656262 39.19863333 59.46956139 22.54 0.85 303.89
26 6294598 38.49821666 52.96059645 20.66 0.90 273.16
28 4678185 37.77295000 45.39241588 18.95 0.85 249.68
```

Importing the output CSV into LibreOffice and setting it to separate values via spaces is a good first step before importing into Google Sheets or elsewhere.

## Notes

- \* Input video must be a raw `.y4m` video, like some of the videos found in [Derf's Test Media Collection](https://media.xiph.org/video/derf/)
- \*\* I am aware that the XPSNR creators prefer to use the minimum of these three values