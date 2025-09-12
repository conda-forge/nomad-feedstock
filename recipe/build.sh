#!/bin/bash

set -euxo pipefail

export GO111MODULE=on
(
  # Set GOARCH based on build_platform to install native binaries
  export GOBIN="${BUILD_PREFIX}/bin"
  export CC="${CC_FOR_BUILD}"
  export LDFLAGS="${LDFLAGS//$PREFIX/$BUILD_PREFIX}"
  case "$build_platform" in
    osx-64)
      export GOARCH=amd64
      ;;
    osx-arm64)
      export GOARCH=arm64
      ;;
    linux-64)
      export GOARCH=amd64
      ;;
    linux-aarch64)
      export GOARCH=arm64
      ;;
    *)
     echo "build_platform ${build_platform} not supported" >&2
     exit 1
     ;;
  esac
  make deps
)

# We could run "make prerelease" here instead but this fails as some files were
# already created during the creation of source tarball.
make ember-dist static-assets

case "$target_platform" in
  linux-64)
    target=linux_amd64
    ;;
  linux-aarch64)
    target=linux_arm64
    ;;
  osx-64)
    target=darwin_amd64
    ;;
  osx-arm64)
    target=darwin_arm64
    ;;
  *)
    echo "target_platform $target_platform not supported" >&2
    exit 1
    ;;
esac
make pkg/$target/nomad

# XXX Workaround for "make" above installing lots of things into $PREFIX/bin.
rm -rf $PREFIX/bin
mkdir -p $PREFIX/bin
cp pkg/$target/nomad $PREFIX/bin

# Nomad is a bit tricky with its licenses.
# If we are not careful, it will end in a loop.
# The ignored licenses are added manually in the recipe definition.
chmod -R u+rw gopath
rm -rf gopath
export GOPATH=$(dirname $(pwd))
# All hashicorp products have the same license
go-licenses save . --save_path=./license-files \
	--ignore github.com/hashicorp/nomad/api \
	--ignore github.com/hashicorp/cronexpr \
	--ignore github.com/hashicorp/vault \
	--ignore github.com/hashicorp/vic \
	--ignore github.com/tj/go-spin \
	--ignore github.com/jmespath/go-jmespath \
	--ignore github.com/hashicorp/nomad
