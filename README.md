# BP-BANDIT-STEP

Bandit step is a security linter for Python source code, utilizing the ast module from the Python standard library.

## Setup
* Clone the code available at [BP-BANDIT-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-BANDIT-STEP.git)
* Build the docker image
```
git submodule init
git submodule update
docker build -t ot/bandit:0.1 .