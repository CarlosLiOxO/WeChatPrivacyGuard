# Third-party notices

The repository's proprietary license applies only to original project
materials. The following component remains under its own license.

## MobileFaceNet

- Project: `foamliu/MobileFaceNet`
- Source: <https://github.com/foamliu/MobileFaceNet>
- Included object: a modified Core ML conversion of the `v1.0`
  `mobilefacenet.pt` weights
- License: Apache License 2.0
- Full license text: `ThirdPartyLicenses/Apache-2.0.txt`

Modifications made by 李翰铭 / WeChat Privacy Guard:

- Added torchvision-compatible input normalization.
- Added horizontal-flip test-time augmentation and embedding summation.
- Added L2 output normalization.
- Converted weights to a float16 Core ML ML Program for macOS.

The upstream-reported benchmark is not a warranty or an accuracy claim for
this product. MobileFaceNet and its contributors provide the component on an
"AS IS" basis under the Apache License 2.0.
