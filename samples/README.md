# Nomad Dispatch Transcoding Samples

This folder holds some sample files that we can use to testing our transcode
service. All the videos are made available to the public by
[NASA](https://www.nasa.gov) or [NOAA](http://www.noaa.gov).

The input files are just a newline seperated list of input files. The provided
`bin/dispatch.sh` script just loops through the file and dispatches a job for
the "small" and "large" profile for each video.
