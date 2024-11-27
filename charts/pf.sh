ingressSubdomain=apps
baseDomain=dev.example.com
while [ true ]
do
  address=`oc get svc -n openshift-ingress|grep -i router-apps |awk '{print $4}'`
  if [[ $address =~ "amazonaws.com" ]]
  then
    echo "result = Cluster is $address"
      break
  fi
  ((i++))
  if [ "$i" == '2' ]
    then
      echo "Number $i!"
      exit 1
  fi
  echo "Address not available yet for load balancer."
  echo "address  = $address"
  sleep 30
done
cat <<EOF >record.json
{
  "Comment": "CREATE/DELETE/UPSERT a record ",
  "Changes": [{
  "Action": "CREATE",
    "ResourceRecordSet": {
        "Name": "*.$ingressSubdomain.$baseDomain",
        "Type": "CNAME",
        "TTL": 300,
      "ResourceRecords": [{ "Value": "$address"}]
    }
  }]
}
EOF
