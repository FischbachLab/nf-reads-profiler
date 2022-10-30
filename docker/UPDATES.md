# Change log for Dockerfile

## tag: maf-20221028-a1; latest

[Source](https://github.com/biobakery/biobakery/blob/ed6d4f32fd46af429e1d640cd55f9f4fbcdbede8/docker/workflows/Dockerfile)

Make fewest changes possible to use the latest versions of `Humann` and `Metaphlan`.

- Updated `kneaddata` from version `latest` to `0.12.0`
- Updated `humann` from version `3.0.0.alpha.3` to `3.6`
- Updated `phylophlan` from version `0.1.0` to `3.0.3`
- Updated `numpy` from version `1.14.5` to `1.19.5`
- Updated `metaphlan` from version `3.0.7` to `4.0.3`
- Removed step to build the metaphlan database within the container.
  - required a lot of time and heftier machine to download and index the database.
  - we install it on EFS separately. Should help with the size of the image.
- Updated `anadama2` from version `0.7.9` to `0.10.0`
- Updated `biobakery_workflows` from version `3.0.0-alpha.6` to `3.1`.
