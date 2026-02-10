#!/usr/bin/env bash
# Run all FHIR setup operations in order
cd "$(dirname "$0")/curl"

echo ">>> Running L00_1_T01"
./L00_1_T01.sh

echo ">>> Running L00_1_T02"
./L00_1_T02.sh

echo ">>> Running L00_1_T03"
./L00_1_T03.sh

echo ">>> Running L00_1_T04"
./L00_1_T04.sh

echo ">>> Running L01_1_T01"
./L01_1_T01.sh

echo ">>> Running L01_1_T02"
./L01_1_T02.sh

echo ">>> Running L01_1_T03"
./L01_1_T03.sh

echo ">>> Running L01_1_T04"
./L01_1_T04.sh

echo ">>> Running L01_1_T05"
./L01_1_T05.sh

echo ">>> Running L01_1_T06"
./L01_1_T06.sh

echo ">>> Running L01_2_T01"
./L01_2_T01.sh

echo ">>> Running L01_2_T02"
./L01_2_T02.sh

echo ">>> Running L01_3_T01"
./L01_3_T01.sh

echo ">>> Running L01_3_T02"
./L01_3_T02.sh

echo ">>> Running L01_3_T03"
./L01_3_T03.sh

echo ">>> Running L01_3_T04"
./L01_3_T04.sh

echo ">>> Running L01_3_T04"
./L01_3_T04.sh

echo ">>> Running L01_3_T05"
./L01_3_T05.sh

echo ">>> Running L02_1_T01"
./L02_1_T01.sh

echo ">>> Running L02_1_T02"
./L02_1_T02.sh

echo ">>> Running L02_1_T03"
./L02_1_T03.sh

echo ">>> Running L02_1_T04"
./L02_1_T04.sh

echo ">>> Running L02_1_T05"
./L02_1_T05.sh

echo ">>> Running L03_1_T01"
./L03_1_T01.sh

echo ">>> Running L03_1_T02"
./L03_1_T02.sh

echo ">>> Running L03_1_T03"
./L03_1_T03.sh

echo ">>> Running L03_1_T04"
./L03_1_T04.sh

echo ">>> Running L03_2_T01"
./L03_2_T01.sh

echo ">>> Running L03_2_T02"
./L03_2_T02.sh

echo ">>> Running L03_2_T03"
./L03_2_T03.sh

echo ">>> Running L03_2_T04"
./L03_2_T04.sh

echo ">>> Running L03_3_T01"
./L03_3_T01.sh

echo ">>> Running L03_3_T02"
./L03_3_T02.sh

echo ">>> Running L03_3_T03"
./L03_3_T03.sh

echo ">>> Running L03_3_T03"
./L03_3_T03.sh

echo ">>> Running L03_3_T03"
./L03_3_T03.sh

echo ">>> Running req_036"
./req_036.sh

echo ">>> Running L03_3_T03"
./L03_3_T03.sh

echo ">>> Running L03_3_T04"
./L03_3_T04.sh

echo ">>> Running L03_3_T04"
./L03_3_T04.sh

echo ">>> Running L04_1_T01"
./L04_1_T01.sh

echo ">>> Running L04_1_T02"
./L04_1_T02.sh

echo ">>> Running L04_2_T01"
./L04_2_T01.sh

echo ">>> Running L04_2_T02"
./L04_2_T02.sh

echo ">>> Running req_046"
./req_046.sh

echo ">>> Running req_048"
./req_048.sh
