#!/usr/bin/bash

# Regular Colors
Red='\033[0;31m'          # Red
Black='\033[0;30m'        # Black
Blue='\033[0;34m'         # Blue
# Reset
Color_Off='\033[0m'       # Text Reset

################################################################################
#
#                               Procedures.
#
################################################################################

# -------------------------------------------------------------------------------
#       create_db2_command
#
#       create db2 command in user home directory
#
#       exit 1 (succeeds) command exist, else 0.
# -------------------------------------------------------------------------------
create_db2_command()
{	
	if [ ! -f "~/db2" ]; then						
		cp /QOpenSys/usr/bin/ipcs ~/db2 && chmod +x ~/db2			
	fi	
  
}

# -------------------------------------------------------------------------------
#       check_if_port_is_used
#
#       create db2 command in user home directory
#
#       exit 1 (succeeds) command exist, else 0.
# -------------------------------------------------------------------------------
check_if_port_is_used()
{
	JOB_USED_PORT="X"	

	create_db2_command	

    # get server port from configuration
    USED_PORT=$(grep "port" $1 | awk '{print $2}' | head -n 1)        

	if [[ "${USED_PORT}" = "" ]]; then 
		echo -e "${Red}No port found${Color_Off}"		
		return 0
	fi

    # get job that use the port      	
    #JOB_USED_PORT=$(db2 "select distinct job_name from QSYS2.NETSTAT_JOB_INFO where local_port='$USED_PORT'" |\
    #              awk '{printf "%s ",$0} END {print ""}' |\
    #              awk '{print $3}')                         
                  
    JOB_USED_PORT=$(qsh -c "db2 \"select distinct job_name from QSYS2.NETSTAT_JOB_INFO where local_port='$USED_PORT'\"" |\
                    awk '{printf "%s ",$0} END {print ""}' |\
                    awk '{print $3}')

	if [ "$JOB_USED_PORT" = "0" ] || [ "$JOB_USED_PORT" = "" ]; then 
		echo -e "${Blue}Port ${USED_PORT} is not used${Color_Off}"		
		return 0
	fi

	if [[ "${2}" = "" ]]; then 
		read -p "Port ${USED_PORT} is used from job ${JOB_USED_PORT}. Terminate? (Y/N): " TERMINATE_JOB		
		if [[ "${TERMINATE_JOB}" = "N" ]]; then 			
			echo -e "${Red}Application cannot start. Port ${USED_PORT} is used from job ${JOB_USED_PORT}.${Color_Off}"
			exit 1
		fi		
	fi		

	if [[ "${2}" = "N" ]]; then		
		echo -e "${Red}Application cannot start. Port ${USED_PORT} is used from job ${JOB_USED_PORT}.${Color_Off}"
		exit 1 
	else
		echo -e "${Blue}Job ${JOB_USED_PORT} will be terminated ...${Color_Off}"
	fi	

    system "ENDJOB JOB(${JOB_USED_PORT}) OPTION(*IMMED)";
  
}

# -------------------------------------------------------------------------------
#       backup_logfile
#
#       backup logfile
#
#       exit 1 (succeeds), else 0.
# -------------------------------------------------------------------------------
backup_logfile()
{	

	SPRING_LOGGING_NAME=$(grep "name" $1 |\
    	          tail -n1 |\
        	      awk '{print $2}')         	          
        	          
	if [ -f "${SPRING_LOGGING_NAME}" ]; then
	   mv $SPRING_LOGGING_NAME ${SPRING_LOGGING_NAME}_$(date "+%F-%T")	
	fi

  
}

# -------------------------------------------------------------------------------
#       kill_unwanted_process
#
#       kill precess they are not used
#
#       exit 1 (succeeds), else 0.
# -------------------------------------------------------------------------------
kill_unwanted_process()
{	

	# Kill start process
    ps -ef | grep 'java' | grep "${1}" | awk '{print $2}' | xargs kill
  
}


################################################################################
#
#                               Main
#
################################################################################

# Default values of arguments
CONFIG_FILE=
PROJECT_DIR=
TERMINATE_JOB=""

echo -e "${Blue}Spring Boot Application wird gestartet ...${Color_Off}"

if [[ $# -eq 0 ]]; then 
	echo -e "${BBlack}Use: \n\
  -f / --config-file Configuration file of spring boot application\n\  
              Example: /OpenSource/configs/si-ibmi-run-spring-boot-app/application.yml
  -p / --project-dir Project directory\n\
              Example: /OpenSource/si-ibmi-run-spring-boot-app/gui/$  
  -y / --yes Terminate job if port is used              
  -n / --no Terminate application, if port is used{Color_Off}"
fi

# Loop through arguments and process them
for arg in "$@"; do		
	case "$arg" in
        -f|--config-file)
          CONFIG_FILE="$2"
          shift # Remove argument name from processing
        ;;
        -p|--project-dir)
          PROJECT_DIR="$2"
          shift # Remove argument name from processing
        ;;             
        -y|--yes)
          TERMINATE_JOB="Y"
          shift # Remove argument name from processing
        ;;   
        -n|--no)
          TERMINATE_JOB="N"
          shift # Remove argument name from processing
		;;  
        *)
          shift # Remove generic argument from processing
        ;;
	esac
done

SPRING_APP_FILE=$(find ${PROJECT_DIR}target -name '*.jar')

check_if_port_is_used ${CONFIG_FILE} ${TERMINATE_JOB}

backup_logfile ${CONFIG_FILE}

# Run app
java -Dspring.config.additional-location=$CONFIG_FILE\
     -DHOSTNAME=$(hostname)\
     -jar ${SPRING_APP_FILE} &     

sleep 1

kill_unwanted_process ${PROJECT_DIR}

echo -e "${Red}CONFIG_FILE=${CONFIG_FILE}"
echo -e "PROJECT_DIR=${PROJECT_DIR}"
echo -e "TERMINATE_JOB=${TERMINATE_JOB}${Color_Off}"
