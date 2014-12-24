#!/bin/bash

#this code has to be executed in the fuseki folder?


echo Running program...

#startup server in background
./fuseki-server --update --mem /ds >& test.log &

#Wait for startup for 10 seconds
sleep 10

./s-put http://localhost:3030/ds/data default testdata.rdf
#./s-query --service http://localhost:3030/ds/query 'SELECT * {?s ?p ?o}'

OUTPUT=''

MVM() {
    local SUMOFSCORES='PREFIX link:<http://link> 
    PREFIX score:<http://scoreiter'
    SUMOFSCORES+="$2"'> PREFIX xsd:<http://www.w3.org/2001/XMLSchema#> 
    SELECT ?src (SUM(xsd:double(?score)) AS ?totalScore) 
    {?nid score: ?score .
    ?src link: ?dst .
    FILTER(?dst = ?nid) 
    } GROUP BY ?src'

    #mass deletion of old scores
    local DELETESCORES='PREFIX score:<http://scoreiter'
    DELETESCORES+="$1"'> DELETE {?s ?p ?o} WHERE {?s ?p ?o . 
    FILTER (?p = score:)}'

    #uses scores from previous calculation
    local SUMOFSQUARES='PREFIX score:<http://scoreiter'
    SUMOFSQUARES+="$1"
    SUMOFSQUARES+='> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> 
    SELECT (SUM(xsd:double(?score) * xsd:double(?score)) as ?vectorSum) 
    {?s score: ?score}'

    local VECTORSUM=0

    ./s-query --service http://localhost:3030/ds/query "$SUMOFSCORES" --output=xml > temp.xml
    
    #array of vector names to insert
    local v=$(awk -F '[<>]' '/uri/{print $3}' temp.xml)
    INS_VECTORS=($v)

    #array of vector scores to insert
    local s=$(awk -F '[<>]' '/literal/{print $3}' temp.xml)
    INS_SCORES=($s)

    local UPDATESTRING=''

    for i in "${!INS_VECTORS[@]}"; do
        ELEM='<'${INS_VECTORS[$i]}'>'
        ELEM+=' <http://scoreiter'"$1"'> '
        ELEM+='"'${INS_SCORES[$i]}'"'

        UPDATESTRING+='INSERT DATA {'$ELEM'}; '

    done
    #echo $UPDATESTRING

    ./s-update --service http://localhost:3030/ds/update "$UPDATESTRING"

    ./s-query --service http://localhost:3030/ds/query "$SUMOFSQUARES" --output=xml > temp.xml
    
    local SUMSQUARE=$(awk -F '[<>]' '/literal/{print $3}' temp.xml)
    #removes scientific notation
    SUMSQUARE=$(echo $SUMSQUARE | awk '{ print sprintf("%.20f", $1); }')
    
    local VECTORSUM=$(echo "sqrt($SUMSQUARE)" | bc -l)
    #echo $VECTORSUM

    ./s-update --service http://localhost:3030/ds/update "$DELETESCORES"

    local INSERTSTRING=''
    for i in "${!INS_VECTORS[@]}"; do
        OLDSCORE=${INS_SCORES[$i]}
        OLDSCORE=$(echo $OLDSCORE | awk '{ print sprintf("%.20f", $1); }')

        NEWSCORE=$(echo "$OLDSCORE / $VECTORSUM" | bc -l)

        ELEM='<'${INS_VECTORS[$i]}'>'
        ELEM+=' <http://scoreiter'"$1"'> '
        ELEM+='"'$NEWSCORE'"'

        INSERTSTRING+='INSERT DATA {'$ELEM'}; '
        OUTPUT+=${INS_VECTORS[$i]}', '"$1"', '$NEWSCORE'\n'
    done

    ./s-update --service http://localhost:3030/ds/update "$INSERTSTRING"
}   

ITERNO=1

while [ $ITERNO -lt 50 ]; do
    ITERNO=$[$ITERNO+1]
    MVM $ITERNO $[ITERNO-1] 
done

printf "$OUTPUT"

wait

