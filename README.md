# resize_zippedimage

Bash script to resize & convert archived images into jpg. Also converts archive format to zip.

## Usage

```
resize_zippedimage.sh <files>
files: Supports zip/rar/7z/cbz archive files. if no arguments given "*.{zip,rar,7z,cab}" is used as default.
```

## How it works

- Target file: zip/rar/7z/cbz archive files which include jpg/jpeg/png image.
- Resize large images (height > 2400px).
- Convert png images into jpg.
- Shrink jpg image file size if possible (re-encode image with --quality 90).
- Writes new archive files with zip format.
- Original archive files are stored in `org` directory.

## Target environment

Linux. Might be run on MacOS (not tested).

### Install

`sudo apt-get install unar unrar zip imagemagick`

## Author

Kunio Nooma (nooma.kunio@gmail.com)

## License

    Copyright (c) 2018 Kunio Nooma <nooma.kunio@gmail.com>
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
       http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
