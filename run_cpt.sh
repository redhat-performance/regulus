#/bin/bash
#
# Main script called by Prow after Crucible and Regulus have been installed.
#
source bootstrap.sh
./bin/reg-smart-config      # Fix lab.config. Prow unlikely to have created a perfect lab.config
source bootstrap.sh         # Pick up the updated lab.config
make init-lab
pushd templates/uperf/TEST
bash setmode one            # Make Prow Regulus job super short for now.
popd
make init-jobs
make jobs

