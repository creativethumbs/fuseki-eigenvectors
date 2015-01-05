#!/bin/bash

#this code has to be executed in the fuseki folder?


echo Running program...

mydir="${HOME}/Desktop"

#startup server in background
./fuseki-server --update --mem /ds &
pid=$!
echo $pid

#Wait for startup for 10 seconds
sleep 10

date1=$(date +"%s")

./s-put http://localhost:3030/ds/data default LBNLdata.rdf

OUTPUT=''

tempfile=$mydir/temp.xml

CP() {
    local SUMOFSCORES_A='PREFIX hasdest:<http://has_dest> 
    PREFIX onport:<http://on_port> 
    PREFIX bscore:<http://vector-b-score> 
    PREFIX cscore:<http://vector-c-score> 
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> 
    SELECT ?srcip (SUM(xsd:double(?bscore) * xsd:double(?cscore)) AS ?totalScore) 
    {?vector_b bscore: ?bscore . 
    ?vector_c cscore: ?cscore . 
    ?srcip hasdest: ?dstip . 
    ?srcip onport: ?portnum . 
    FILTER(?dstip = ?vector_b && ?portnum = ?vector_c) 
    } GROUP BY ?srcip'

    local SUMOFSCORES_B='PREFIX hasdest:<http://has_dest> 
    PREFIX onport:<http://on_port> 
    PREFIX ascore:<http://vector-a-score> 
    PREFIX cscore:<http://vector-c-score> 
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> 
    SELECT ?srcip (SUM(xsd:double(?ascore) * xsd:double(?cscore)) AS ?totalScore) 
    {?vector_a ascore: ?ascore . 
    ?vector_c cscore: ?cscore . 
    ?srcip hasdest: ?dstip . 
    ?srcip onport: ?portnum . 
    FILTER(?dstip = ?vector_a && ?portnum = ?vector_c) 
    } GROUP BY ?srcip'

    local SUMOFSCORES_C='PREFIX hasdest:<http://has_dest> 
    PREFIX onport:<http://on_port> 
    PREFIX ascore:<http://vector-a-score> 
    PREFIX bscore:<http://vector-b-score> 
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> 
    SELECT ?srcip (SUM(xsd:double(?ascore) * xsd:double(?bscore)) AS ?totalScore) 
    {?vector_a ascore: ?ascore . 
    ?vector_b bscore: ?bscore . 
    ?srcip hasdest: ?dstip . 
    ?srcip hasdest: ?dstip2 . 
    FILTER(?dstip = ?vector_a && ?dstip2 = ?vector_b) 
    } GROUP BY ?srcip'


    local SUMOFSQUARES_A='PREFIX score:<http://vector-a-score> 
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> 
    SELECT (SUM(xsd:double(?score) * xsd:double(?score)) as ?vectorSum) 
    {?s score: ?score}'

    local SUMOFSQUARES_B='PREFIX score:<http://vector-b-score> 
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> 
    SELECT (SUM(xsd:double(?score) * xsd:double(?score)) as ?vectorSum) 
    {?s score: ?score}'

    local SUMOFSQUARES_C='PREFIX score:<http://vector-c-score> 
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> 
    SELECT (SUM(xsd:double(?score) * xsd:double(?score)) as ?vectorSum) 
    {?s score: ?score}'
 
    local UPDATESTRING=''

    # first equation ---------------------------------------------
    ./s-query --service http://localhost:3030/ds/query "$SUMOFSCORES_A" --output=xml > $tempfile
    
    #array of vector names to insert
    local v=$(awk -F '[<>]' '/uri/{print $3}' $tempfile)
    INS_VECTORS_A=($v)

    #array of vector scores to insert
    local s=$(awk -F '[<>]' '/literal/{print $3}' $tempfile)
    INS_SCORES_A=($s)

    for i in "${!INS_VECTORS_A[@]}"; do
        if [ "$i" -gt 0 ] ; then
            ELEM='<'${INS_VECTORS_A[$i]}'> <http://vector-a-score> '
            ELEM2='<'${INS_VECTORS_A[$i]}'> <http://vector-a-score> ' 
            ELEM+='"'${INS_SCORES_A[$i]}'"'

            UPDATESTRING+='DELETE {'$ELEM2' ?o} INSERT {'$ELEM'} WHERE {'$ELEM2' ?o }; '
            
        fi
    done

    # second equation ---------------------------------------------
    ./s-query --service http://localhost:3030/ds/query "$SUMOFSCORES_B" --output=xml > $tempfile
    
    #array of vector names to insert
    local v=$(awk -F '[<>]' '/uri/{print $3}' $tempfile)
    INS_VECTORS_B=($v)

    #array of vector scores to insert
    local s=$(awk -F '[<>]' '/literal/{print $3}' $tempfile)
    INS_SCORES_B=($s)

    for i in "${!INS_VECTORS_B[@]}"; do
        if [ "$i" -gt 0 ] ; then
            ELEM='<'${INS_VECTORS_B[$i]}'> <http://vector-b-score> '
            ELEM2='<'${INS_VECTORS_B[$i]}'> <http://vector-b-score> ' 
            ELEM+='"'${INS_SCORES_B[$i]}'"'

            UPDATESTRING+='DELETE {'$ELEM2' ?o} INSERT {'$ELEM'} WHERE {'$ELEM2' ?o }; '
            
        fi
    done

    # third equation ---------------------------------------------
    ./s-query --service http://localhost:3030/ds/query "$SUMOFSCORES_C" --output=xml > $tempfile
    
    #array of vector names to insert
    local v=$(awk -F '[<>]' '/uri/{print $3}' $tempfile)
    INS_VECTORS_C=($v)

    #array of vector scores to insert
    local s=$(awk -F '[<>]' '/literal/{print $3}' $tempfile)
    INS_SCORES_C=($s)

    for i in "${!INS_VECTORS_C[@]}"; do
        if [ "$i" -gt 0 ] ; then
            ELEM='<'${INS_VECTORS_C[$i]}'> <http://vector-c-score> '
            ELEM2='<'${INS_VECTORS_C[$i]}'> <http://vector-c-score> ' 
            ELEM+='"'${INS_SCORES_C[$i]}'"'

            UPDATESTRING+='DELETE {'$ELEM2' ?o} INSERT {'$ELEM'} WHERE {'$ELEM2' ?o }; '
            
        fi
    done

    #echo "$UPDATESTRING"
    ./s-update --service http://localhost:3030/ds/update "$UPDATESTRING"


    #gets the vectorSum for the first vector table -----------------------------------
    ./s-query --service http://localhost:3030/ds/query "$SUMOFSQUARES_A" --output=xml > $tempfile

    local SUMSQUARE_A=$(awk -F '[<>]' '/literal/{print $3}' $tempfile)
    #removes scientific notation
    SUMSQUARE_A=$(echo $SUMSQUARE_A | awk '{ print sprintf("%.20f", $1); }')

    echo "$SUMSQUARE_A"
    local VECTORSUM_A=$(echo "sqrt($SUMSQUARE_A)" | bc -l)
    echo "$VECTORSUM_A"
    
    #gets the vectorSum for the second vector table -----------------------------------
    ./s-query --service http://localhost:3030/ds/query "$SUMOFSQUARES_B" --output=xml > $tempfile

    local SUMSQUARE_B=$(awk -F '[<>]' '/literal/{print $3}' $tempfile)
    #removes scientific notation
    SUMSQUARE_B=$(echo $SUMSQUARE_B | awk '{ print sprintf("%.20f", $1); }')
    
    echo "$SUMSQUARE_B"
    local VECTORSUM_B=$(echo "sqrt($SUMSQUARE_B)" | bc -l)
    echo "$VECTORSUM_B"
    #gets the vectorSum for the third vector table -----------------------------------
    ./s-query --service http://localhost:3030/ds/query "$SUMOFSQUARES_C" --output=xml > $tempfile

    local SUMSQUARE_C=$(awk -F '[<>]' '/literal/{print $3}' $tempfile)
    #removes scientific notation
    SUMSQUARE_C=$(echo $SUMSQUARE_C | awk '{ print sprintf("%.20f", $1); }')
    
    echo "$SUMSQUARE_C"
    local VECTORSUM_C=$(echo "sqrt($SUMSQUARE_C)" | bc -l)
     echo "$VECTORSUM_C"
    
    #performs big update ----------------------------------------------------
    echo "performing big update..."

    local BIGUPDATESTRING=''

    if [ $(echo " $VECTORSUM_A > 0" | bc) -eq 0 ] ; then 
        for i in "${!INS_VECTORS_A[@]}"; do
            OLDSCORE=${INS_SCORES_A[$i]}
            OLDSCORE=$(echo $OLDSCORE | awk '{ print sprintf("%.20f", $1); }')

            NEWSCORE=$(echo "$OLDSCORE / $VECTORSUM_A" | bc -l)

            ELEM='<'${INS_VECTORS_A[$i]}'>'
            ELEM+=' <http://vector-a-score> '
            ELEM2="$ELEM '"'$NEWSCORE'"'"

            BIGUPDATESTRING+='DELETE {'$ELEM' ?o} INSERT {'$ELEM2'} WHERE {'$ELEM' ?o }; '
            OUTPUT+=${INS_VECTORS_A[$i]}', '"$1"', '$NEWSCORE'\n'
        done
    fi

    if [ $(echo " $VECTORSUM_B > 0" | bc) -eq 0 ] ; then 
        for i in "${!INS_VECTORS_B[@]}"; do
            OLDSCORE=${INS_SCORES_B[$i]}
            OLDSCORE=$(echo $OLDSCORE | awk '{ print sprintf("%.20f", $1); }')

            NEWSCORE=$(echo "$OLDSCORE / $VECTORSUM_B" | bc -l)

            ELEM='<'${INS_VECTORS_B[$i]}'>'
            ELEM+=' <http://vector-b-score> '
            ELEM2="$ELEM '"'$NEWSCORE'"'"

            BIGUPDATESTRING+='DELETE {'$ELEM' ?o} INSERT {'$ELEM2'} WHERE {'$ELEM' ?o }; '
            OUTPUT+=${INS_VECTORS_B[$i]}', '"$1"', '$NEWSCORE'\n'
        done
    fi

    if [ $(echo " $VECTORSUM_C > 0" | bc) -eq 0 ] ; then 
        for i in "${!INS_VECTORS_C[@]}"; do
            OLDSCORE=${INS_SCORES_C[$i]}
            OLDSCORE=$(echo $OLDSCORE | awk '{ print sprintf("%.20f", $1); }')

            NEWSCORE=$(echo "$OLDSCORE / $VECTORSUM_C" | bc -l)

            ELEM='<'${INS_VECTORS_C[$i]}'>'
            ELEM+=' <http://vector-c-score> '
            ELEM2="$ELEM '"'$NEWSCORE'"'"

            BIGUPDATESTRING+='DELETE {'$ELEM' ?o} INSERT {'$ELEM2'} WHERE {'$ELEM' ?o }; '
            OUTPUT+=${INS_VECTORS_C[$i]}', '"$1"', '$NEWSCORE'\n'
        done
    fi

    ./s-update --service http://localhost:3030/ds/update "$BIGUPDATESTRING"
    
}   

ITERNO=1

while [ $ITERNO -lt 20 ]; do
    ITERNO=$[$ITERNO+1]
    CP $ITERNO
    echo "done with iter "$ITERNO
done

resultfile=$mydir/CPresult.txt

printf "$OUTPUT" > $resultfile

date2=$(date +"%s")

diff=$(($date2-$date1))
timingfile=$mydir/CPtime.txt
echo "$(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed." > $timingfile


wait

