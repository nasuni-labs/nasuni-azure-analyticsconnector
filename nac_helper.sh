#!/bin/bash
resource_group="$1"
resource_list_json=""
database_name="Nasuni"
container_name="Metrics"

echo " Argument received is : $resource_group"

get_resource_list () {
    while [ -z "$resource_list_json" ]; do
        resource_list_json=$(az resource list --resource-group "$resource_group")
    done
}

get_resource_list

max_minutes=10
current_minute=0

while [ "$current_minute" -lt "$max_minutes" ]; do

    cosmosdb_account_name=$(echo "$resource_list_json" | jq -r '.[] | select(.type == "Microsoft.DocumentDb/databaseAccounts") | .name')
    echo "Cosmos DB Account Name: $cosmosdb_account_name"

    if [ -n "$cosmosdb_account_name" ]; then
        echo "Cosmos DB has been created."
        break
    else
        echo "Check $current_minute Cosmos DB has not been created yet."
        sleep 60
        current_minute=$((current_minute + 1))
        get_resource_list
        fi
done

sleep 600

echo "Trying to retrieve count of objects in cosmos db"

result=$(az cosmosdb sql container show --account-name "$cosmosdb_account_name" --resource-group "$resource_group" --database-name "$database_name" --name "$container_name")
count=$(echo "$result" | jq -r '.resource.statistics[].documentCount' | awk '{s+=$1} END {print s}')

echo "Document Count in $database_name/$container_name: $count"

if [ "$count" -lt 1 ]; then
        echo "Document count is less than 1. Exiting the script."
        
        pid=$(ps -ef | grep nac_manager | awk '{print $2}')
        echo "pid of nac_manager process is $pid"

        pids=($(pgrep -f 'nac_manager'))

        if [ ${#pids[@]} -gt 0 ]; then
            for pid in "${pids[@]}"; do
                echo "Killing process with PID: $pid"
                kill "$pid"
            done
        fi
        exit 1

else
    echo "Count of objects are greater than 1. No issues"
    fi