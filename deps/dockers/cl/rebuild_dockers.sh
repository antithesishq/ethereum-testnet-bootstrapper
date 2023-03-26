echo "<<<<<<<<<< ANTITHESIS >>>>>>>>>> - Building NIMBUS"
BUILDKIT=1 docker build --registries-conf=`pwd`/../../../registries.conf --no-cache -t nimbus:etb-minimal -f nimbus_minimal.Dockerfile .
echo "<<<<<<<<<< ANTITHESIS >>>>>>>>>> - Building TEKU"
BUILDKIT=1 docker build --registries-conf=`pwd`/../../../registries.conf --no-cache -t teku:etb-minimal -f teku_minimal.Dockerfile .
echo "<<<<<<<<<< ANTITHESIS >>>>>>>>>> - Building LODESTAR"
BUILDKIT=1 docker build --registries-conf=`pwd`/../../../registries.conf --no-cache -t lodestar:etb-minimal -f lodestar_minimal.Dockerfile .
echo "<<<<<<<<<< ANTITHESIS >>>>>>>>>> - Building LIGHTHOUSE"
BUILDKIT=1 docker build --registries-conf=`pwd`/../../../registries.conf --no-cache -t lighthouse:etb-minimal -f lighthouse_minimal.Dockerfile .
echo "<<<<<<<<<< ANTITHESIS >>>>>>>>>> - Building PRYSM"
BUILDKIT=1 docker build --registries-conf=`pwd`/../../../registries.conf --no-cache -t prysm:etb-minimal -f prysm_minimal_inst.Dockerfile .
