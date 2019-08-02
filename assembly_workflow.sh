#!/bin/bash

# usage message
if [[ ! -f $1 ]]; then
	echo "usage: $0 INPUT_FA"
	exit 1
fi

# configuration
CPU=8

# filenames definitions
INPUT_FA=$1
SHASTA=shasta.$1.fa
ALIGN=align.$1.bam
MARGIN_POLISH=margin_polish.$1.fa
HELEN=helen.$1.fa



# Shasta
# https://github.com/tpesout/shasta/blob/docker/docs/Docker.html
# https://github.com/tpesout/shasta/tree/docker/docker
if [[ ! -f $SHASTA ]]; then
	echo "RUNNING SHASTA"
	docker run -v `pwd`:/data tpesout/shasta:latest --input $INPUT_FA
	if [[ ! -f ShastaRun/Assembly.fasta ]] ; then 
		echo "ERROR: an error occurred running Shasta"
		exit 2
	fi
	mv ShastaRun/Assembly.fasta $SHASTA
fi


# Align
# https://github.com/UCSC-nanopore-cgl/NaRLE/tree/master/docker/minimap2
# https://github.com/UCSC-nanopore-cgl/NaRLE/tree/master/docker/samtools_sort
# https://github.com/UCSC-nanopore-cgl/NaRLE/tree/master/docker/samtools_view
# https://github.com/BD2KGenomics/cgl-docker-lib/tree/master/samtools
if [[ ! -f $ALIGN ]]; then
	echo "RUNNING MINIMAP"
	docker run -v `pwd`:/data tpesout/minimap2:latest -ax map-ont -t $CPU /data/$SHASTA /data/$INPUT_FA

        if [[ ! -f minimap2.sam ]] ; then 
                echo "ERROR: an error occurred running minimap2"
                exit 3
        fi
	echo "RUNNING SAMTOOLS SORT"
	docker run -v `pwd`:/data tpesout/samtools_sort:latest /data/minimap2.sam -@ $CPU
	if [[ ! -f samtools_sort.bam ]]; then
		echo "ERROR: an error occurred running samtools sort"
                exit 4
        fi
	echo "RUNNING SAMTOOLS VIEW"
	docker run -v `pwd`:/data tpesout/samtools_view:latest -hb -F 0x104 /data/samtools_sort.bam
	if [[ ! -f samtools_view.out ]]; then
                echo "ERROR: an error occurred running samtools view"
                exit 5
        fi
	# cleanup and index
	mv samtools_view.out $ALIGN
	rm samtools_sort.bam
	rm minimap2.sam
	docker run -v `pwd`:/data quay.io/ucsc_cgl/samtools:1.8--cba1ddbca3e1ab94813b58e40e56ab87a59f1997 index -@ $CPU /data/$ALIGN
fi

# MarginPolish
# https://github.com/UCSC-nanopore-cgl/MarginPolish/tree/master/docker
if [[ ! -f $MARGIN_POLISH ]]; then
	echo "RUNNING MARGIN POLISH"
	mkdir -p marginPolish
	docker run -v `pwd`:/data tpesout/margin_polish:latest /data/$ALIGN /data/$SHASTA /opt/MarginPolish/params/allParams.np.human.guppy-ff-235.json -t $CPU -o /data/marginPolish/ -f
	if [[ ! -f marginPolish/output.fa ]]; then
                echo "ERROR: an error occurred running MarginPolish"
                exit 6
        fi
	if [[ ! -f marginPolish/output.T00.h5 ]]; then
                echo "ERROR: an error occurred generating MarginPolish images"
                exit 7
        fi
	mv marginPolish/output.fa $MARGIN_POLISH
fi

# HELEN
# https://github.com/kishwarshafin/helen/tree/master/Dockerfile
if [[ ! -f $HELEN ]]; then
	echo "RUNNING HELEN"
	if [[ ! -f r941_flip235_v001.pkl ]] ; then 
		wget https://storage.googleapis.com/kishwar-helen/helen_trained_models/v0.0.1/r941_flip235_v001.pkl 
	fi
	echo "You gotta go run HELEN on your own: https://github.com/kishwarshafin/helen"
	#sudo docker run -v `pwd`:/data kishwars/helen:0.0.1.cpu call_consensus.py -i /data/marginPolish -m r941_flip235_v001.pkl -o helen -w $CPU
	#docker run -v `pwd`:/data kishwars/helen:0.0.1.cpu stitch.py 
fi

# success
echo "Fin."


