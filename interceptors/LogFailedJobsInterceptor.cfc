component {

	property name="settings" inject="coldbox:moduleSettings:cbq";
	property name="javaInstant" inject="java:java.time.Instant";
	property name="qb" inject="provider:QueryBuilder@qb";
	property name="config" inject="provider:Config@cbq";
	property name="log" inject="logbox:logger:{this}";

	function onCBQJobFailed( event, data ) {
		if ( !variables.settings.logFailedJobs ) {
			return;
		}

		var connectionName = arguments.data.job.getConnection();
		param connectionName = variables.config.getDefaultConnectionName();
		var queueName = arguments.data.job.getQueue();

		if ( isNull( queueName ) ) {
			var connection = variables.config.getConnection( connectionName );
			queueName = connection.getDefaultQueue();
		}

		var options = {};
		param variables.settings.logFailedJobsProperties.queryOptions = {};
		structAppend( options, variables.settings.logFailedJobsProperties.queryOptions );
		if (
			variables.settings.logFailedJobsProperties.keyExists( "datasource" ) && (
				!isSimpleValue( variables.settings.logFailedJobsProperties.datasource ) || variables.settings.logFailedJobsProperties.datasource != ""
			)
		) {
			options[ "datasource" ] = variables.settings.logFailedJobsProperties.datasource;
		}

		param variables.settings.logFailedJobsProperties.tableName = "cbq_failed_jobs";
		var logData = {
			"connection" : connectionName,
			"queue" : queueName,
			"mapping" : arguments.data.job.getMapping(),
			"memento" : serializeJSON( arguments.data.job.getMemento() ),
			"properties" : serializeJSON( arguments.data.job.getProperties() ),
			"exceptionType" : {
				"value" : arguments.data.exception.type ?: "",
				"cfsqltype" : "CF_SQL_VARCHAR",
				"null" : ( arguments.data.exception.type ?: "" ) == "",
				"nulls" : ( arguments.data.exception.type ?: "" ) == ""
			},
			"exceptionMessage" : arguments.data.exception.message,
			"exceptionDetail" : {
				"value" : arguments.data.exception.detail ?: "",
				"cfsqltype" : "CF_SQL_VARCHAR",
				"null" : ( arguments.data.exception.detail ?: "" ) == "",
				"nulls" : ( arguments.data.exception.detail ?: "" ) == ""
			},
			"exceptionExtendedInfo" : {
				"value" : arguments.data.exception.extendedInfo ?: "",
				"cfsqltype" : "CF_SQL_VARCHAR",
				"null" : ( arguments.data.exception.extendedInfo ?: "" ) == "",
				"nulls" : ( arguments.data.exception.extendedInfo ?: "" ) == ""
			},
			"exceptionStackTrace" : arguments.data.exception.stackTrace,
			"exception" : serializeJSON( arguments.data.exception ),
			"failedDate" : { "value": getCurrentUnixTimestamp(), "cfsqltype": "CF_SQL_BIGINT" },
			"originalId" : { "value": arguments.data.job.getId(), "cfsqltype": "CF_SQL_VARCHAR" }
		};

		try {
			qb.table( variables.settings.logFailedJobsProperties.tableName )
				.insert(
					values = logData,
					options = options
				);
		} catch ( any e ) {
			log.error( "Failed to log failed job: #e.message#", {
				"log": logData,
				"exception": e
			} );
			rethrow;
		}
	}

	/**
	 * Get the "available at" UNIX timestamp.
	 *
	 * @delay  The delay, in seconds, to add to the current timestamp
	 * @return int
	 */
	private numeric function getCurrentUnixTimestamp( numeric delay = 0 ) {
		return variables.javaInstant.now().getEpochSecond() + arguments.delay;
	}

}
