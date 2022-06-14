#!/bin/bash
# This script creates one mysqldump file per week of the table $table in all 
# databases on the local server that have this prefix: $prefix. 
# It divides them from day 1 to day 7, from day 8 to day 14, from day 15 to day 21
# and from the 22nd to the last day of the month inside the ./backups directory.
# the files are in this format: database_YYYYYY_MM_week_X.sql

# crontab configuration to run the script on each corresponding date
# 0   9  1,8,15,22 		*					* /home/desemax_backups/backup_radacct.sh
# 0   9  31     		1,3,5,7,8,10,12		* /home/desemax_backups/backup_radacct.sh
# 0   9  30     		4,6,9,11			* /home/desemax_backups/backup_radacct.sh
# 0   9  28,29  		2 					* /home/desemax_backups/backup_radacct.sh

#parameters to execute the command with specified backup start and end dates
#./backup_radacct.sh -p 2021-09-01 -u 2021-12-31
#./backup_radacct.sh -p 2021-04-01 -u 2021-08-31
#./backup_radacct.sh -p 2021-01-01 -u 2021-03-31
#./backup_radacct.sh -p 2022-01-01 -u 2022-01-07

# Credentials for mysql and mysqldump command. 
# if the Mysql server is on another host you have to add the parameter in 
# credentials variable used for mysql and mysqldump calls.

#credentials="-uUSER -pPASSWORD"

# with the $credentials variable you can pass the values by the commando line 
# but you will get the following error:
# mysql: [Warning] Using a password on the command line interface can be insecure.
# to avoid this you can use the --login-path=local parameter, this parameter
# stores the mysql login information in a local file
# to configure this data run the following command only once.
# mysql_config_editor set --login-path=local --host=localhost --user=db_user --password

credentials="--login-path=local"

#FLAGS
#enable deletion of the logs after backup
deleteRecords=false
#true if it starts scrolling through the table from the first date it encounters
fromStart=true
#if false, indicate the number of days ago for the backup start date
daysStart=90
#true to backup up to the last date found in the table
toFinal=false
#if false indicate the number of days from $daysStart to be backed up
daysEnd=90
table="userLog"
#dateField that has the date to search for
dateField="dateLog"
#field for sorting the results
orderField="logId"
#--extended-insert=FALSE
dumpParams="--skip-add-locks --no-create-db --no-create-info=FALSE --skip-add-drop-table=TRUE --extended-insert=FALSE --lock-tables=FALSE --quick "

#command="mysql $credentials"
#databases=$($command "-e SHOW databases";)
databases=$(mysql ${credentials} "-e SHOW databases;")
#set a prefix to the DBs to be traversed, to search only for DBs starting with:
prefix="WP_"


currentDay=$(date +%d)
currentMonth=$(date +%m)
currentYear=$(date +%Y)
currentDate=$(date +%s)

YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;36m'
NC='\033[0m' # No Color
clear

while getopts p:u: flag
do
    case "${flag}" in
        p) firstDate=${OPTARG};;
        u) lastDate=${OPTARG};;
    esac
done


if $deleteRecords; then
	echo -e "$RED Se borraran los registros al finalizar el dump."
fi

for db in $databases; do
	if [[ $db =~ ^$prefix ]]
	then
		lendb=$((${#prefix} + 1))
		domain=$(echo $db | cut -c$lendb-)
		#If no date was passed by parameter
		if [ -z $firstDate ]; then
			# TAKE THE FIRST DATE THAT APPEARS IN $table AND START BACKUP
			if $fromStart; then
				firstDate=$(mysql ${credentials} "-BNe USE ${db}; SELECT DATE (${dateField}) FROM ${table} ORDER BY ${table}.${dateField} ASC LIMIT 1;")
			else
				# OR START BACKUP FROM THE LAST $daysStart DAYS
				firstDate=$(date +'%Y-%m-%d' --date="${daysStart} days ago")
			fi
		fi
		if [ -z $lastDate ]; then
			if 	$toFinal; then
				# UNTIL THE LAST DATE IT'S ON $table
				lastDate=$(mysql ${credentials} "-BNe USE ${db}; SELECT DATE (${dateField}) FROM ${table} ORDER BY ${table}.${dateField} DESC LIMIT 1;")
			else
				# OR BACKUP UNTIL $daysEnd 
				lastDate=$(date +'%Y-%m-%d' -d "${firstDate}+${daysEnd} days")
			fi
		fi


		initialDay=$(date -d "$firstDate" +'%d')
		initialMonth=$(date -d "$firstDate" +'%-m')
		
		initialYear=$(date -d "$firstDate" +'%Y')
		loopDay=$initialDay
		loopMonth=$initialMonth
		loopYear=$initialYear
		loopDate=$(date -d "$loopYear-$loopMonth-$loopDay" +%s)
		currentDate=$(date -d "$lastDate" +%s)


        echo -e "${BLUE}****************************************************************************${NC}\n"
    	echo -e "${YELLOW}                        DB PROCESSING: ${domain}\n"
    	echo -e "${GREEN}                  FROM: ${firstDate} TO: ${lastDate}${NC}\n"

		

		count=$(mysql ${credentials} "-BNe USE ${db}; SELECT COUNT(*) FROM ${table} WHERE ${dateField} > '${firstDate}' AND ${dateField} < '${lastDate}'";)
		echo "Number of records: $count"
		echo "Skipping weeks without data..."
		#read -p "Press [ENTER] to start...."
		if [[ $count > 0 ]]
       	then
	        while [[ $loopDate -le $currentDate ]]
	        do
				if ((22<=$loopDay && $loopDay<=31))
				then
					ultimoDiaMes=$(date -d "${loopYear}-${loopMonth}-01 + 1 month - 1 day" +'%d')
					archivo="backups_radacct/${domain}_${loopYear}_${loopMonth}_week_4.sql"
					condicion="${dateField} BETWEEN '${loopYear}-${loopMonth}-${loopDay} 00:00:00' AND '${loopYear}-${loopMonth}-${ultimoDiaMes} 23:59:59' ORDER BY ${orderField}"
					countItera=$(mysql ${credentials} "-BNe USE ${db}; SELECT COUNT(*) FROM ${table} WHERE ${condicion}";)
					if [[ $countItera > 0 ]]
					then
						echo -e "${GREEN}    Creating backup file: "${archivo}" ${NC}"						
				    	mysqldump $credentials $dumpParams "$db" $table --where="$condicion" | sed 's/^CREATE TABLE /CREATE TABLE IF NOT EXISTS /' > $archivo
				    fi
					loopDay=1
					loopMonth=$((10#$loopMonth+1))
					if (($loopMonth >= 13))
					then
						loopMonth=1
						loopYear=$((10#$loopYear + 1))
					fi
				elif ((15<=$loopDay && $loopDay<=21))
				then
					archivo="backups_radacct/${domain}_${loopYear}_${loopMonth}_week_3.sql"
					condicion="${dateField} BETWEEN '${loopYear}-${loopMonth}-${loopDay} 00:00:00' AND '${loopYear}-${loopMonth}-22 23:59:59' ORDER BY ${orderField}"
					countItera=$(mysql ${credentials} "-BNe USE ${db}; SELECT COUNT(*) FROM ${table} WHERE ${condicion}";)
					if [[ $countItera > 0 ]]
					then
						echo -e "${GREEN}    Creating backup file: "${archivo}" ${NC}"
					    mysqldump $credentials $dumpParams "$db" $table --where="$condicion" | sed 's/^CREATE TABLE /CREATE TABLE IF NOT EXISTS /' > $archivo
					fi
					loopDay=22
				elif ((8<=$loopDay && $loopDay<=14))
				then
					archivo="backups_radacct/${domain}_${loopYear}_${loopMonth}_week_2.sql"
					condicion="${dateField} BETWEEN '${loopYear}-${loopMonth}-${loopDay} 00:00:00' AND '${loopYear}-${loopMonth}-15 23:59:59' ORDER BY ${orderField}"
					countItera=$(mysql ${credentials} "-BNe USE ${db}; SELECT COUNT(*) FROM ${table} WHERE ${condicion}";)
					if [[ $countItera > 0 ]]
					then
					    echo -e "${GREEN}    Creating backup file: "${archivo}" ${NC}"
					    mysqldump $credentials $dumpParams "$db" $table --where="$condicion" | sed 's/^CREATE TABLE /CREATE TABLE IF NOT EXISTS /' > $archivo
					fi
					loopDay=15
				elif ((1<=$loopDay && $loopDay<=7))
				then
					archivo="backups_radacct/${domain}_${loopYear}_${loopMonth}_week_1.sql"
					condicion="${dateField} BETWEEN '${loopYear}-${loopMonth}-${loopDay} 00:00:00' AND '${loopYear}-${loopMonth}-7 23:59:59' ORDER BY ${orderField}"
					countItera=$(mysql ${credentials} "-BNe USE ${db}; SELECT COUNT(*) FROM ${table} WHERE ${condicion}";)
					if [[ $countItera > 0 ]]
					then
					    echo -e "${GREEN}    Creating backup file: "${archivo}" ${NC}"
					    mysqldump $credentials $dumpParams "$db" $table --where="$condicion" | sed 's/^CREATE TABLE /CREATE TABLE IF NOT EXISTS /' > $archivo
					fi
					loopDay=8
				fi 
				loopDate=$(date -d "$loopYear-$loopMonth-$loopDay" +%s)
	        done
	        if $deleteRecords; then
				echo -e "${BLUE} DELETING RECORDS: "
				echo -e "		DELETE FROM ${table} WHERE ${dateField} < '${firstDate}'; ${NC}"
				delete=$(mysql ${credentials} "-BNe USE ${db}; DELETE FROM ${table} WHERE ${dateField} < '${firstDate}';")
				echo -e "${RED} ${delete} Deleted records in ${domain}.${table} ${NC} \n"
			fi
	    else
			echo -e "${BLUE} ${domain}.${table} No records in the indicated date range, no backup is created. ${NC}\n"
		fi

	fi
done
echo -e "${BLUE} --- Backup Done ---"
