#!/bin/bash
#  gtransfer - wrapper for tgftp with support for:
#+ * datapathing
#+ * default parameter usage
#+ * ...

:<<COPYRIGHT

Copyright (C) 2010, 2011 Frank Scheiner, HLRS, Universitaet Stuttgart
Copyright (C) 2011, 2012, 2013 Frank Scheiner

The program is distributed under the terms of the GNU General Public License

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

This product includes software developed by members of the DEISA project
www.deisa.org. DEISA is an EU FP7 integrated infrastructure initiative under
contract number RI-222919. 

COPYRIGHT

#  prevent "*" expansion (filename globbing)
set -f

version="0.1.2"
gsiftpUserParams=""

#  path to configuration files (prefer system paths!)
#  For native OS packages:
if [[ -e "/etc/gtransfer" ]]; then
        gtransferConfigurationFilesPath="/etc/gtransfer"
        #  gtransfer is installed in "/usr/bin", hence the base path is "/usr"
        gtransferBasePath="/usr"
        gtransferLibPath="$gtransferBasePath/lib/gtransfer"

#  For installation with "install.sh".
#sed#elif [[ -e "<GTRANSFER_BASE_PATH>/etc" ]]; then
#sed#	gtransferConfigurationFilesPath="<GTRANSFER_BASE_PATH>/etc"
#sed#	gtransferBasePath=<GTRANSFER_BASE_PATH>
#sed#	gtransferLibPath="$gtransferBasePath/lib"

#  According to FHS 2.3, configuration files for packages located in "/opt" have
#+ to be placed here (if you use a provider super dir below "/opt" for the
#+ gtransfer files, please also use the same provider super dir below
#+ "/etc/opt").
#elif [[ -e "/etc/opt/<PROVIDER>/gtransfer" ]]; then
#	gtransferConfigurationFilesPath="/etc/opt/<PROVIDER>/gtransfer"
#	gtransferBasePath="/opt/<PROVIDER>/gtransfer"
#	gtransferLibPath="$gtransferBasePath/lib"
elif [[ -e "/etc/opt/gtransfer" ]]; then
        gtransferConfigurationFilesPath="/etc/opt/gtransfer"
        gtransferBasePath="/opt/gtransfer"
        gtransferLibPath="$gtransferBasePath/lib"

#  For user install in $HOME:
elif [[ -e "$HOME/.gtransfer" ]]; then
        gtransferConfigurationFilesPath="$HOME/.gtransfer"
        gtransferBasePath="$HOME/opt/gtransfer"
        gtransferLibPath="$gtransferBasePath/lib"

#  For git deploy, use $BASH_SOURCE
elif [[ -e "$( dirname $BASH_SOURCE )/../etc" ]]; then
	gtransferConfigurationFilesPath="$( dirname $BASH_SOURCE )/../etc"
	gtransferBasePath="$( dirname $BASH_SOURCE )/../"
	gtransferLibPath="$gtransferBasePath/lib"
fi

gtransferConfigurationFile="$gtransferConfigurationFilesPath/gtransfer.conf"

chunkConfig="$gtransferConfigurationFilesPath/chunkConfig"

#  Set $_LIB so gtransfer and its libraries can find their includes
readonly _LIB="$gtransferLibPath"

readonly __GLOBAL__gtTmpSuffix="#gt#tmp#"
readonly __GLOBAL__gtCacheSuffix="#gt#cache#"

################################################################################
#  INCLUDE LIBRARY FUNCTIONS
################################################################################

. "$_LIB"/exitCodes.bashlib
. "$_LIB"/urlTransfer.bashlib
. "$_LIB"/listTransfer.bashlib
. "$_LIB"/autoOptimization.bashlib

################################################################################


################################################################################
#  FUNCTIONS
################################################################################

#USAGE##########################################################################
usageMsg()
{
        cat <<USAGE

usage: $(basename $0) [--help] ||
       $(basename $0) \\
        --source|-s gsiftpSourceUrl \\
        --destination|-d gsiftpDestinationUrl \\
        [optional params] \\
        [-- gsiftpParameters]

--help gives more information

USAGE
        return
}
#END_USAGE######################################################################


#HELP###########################################################################
helpMsg()
{
        cat <<HELP

$(versionMsg)

SYNOPSIS:

$(basename $0) \\
 --source|-s sourceUrl \\
 --destination|-d destinationUrl \\
 [--verbose|-v] \\
 [--metric|-m dataPathMetric] \\
 [--auto-clean|-a] \\
 [-- gsiftpParameters]

DESCRIPTION:

gtransfer is a wrapper script for tgftp that supports (GridFTP) transfers along
predefined paths by using transit sites. Additionally it supports usage of
default parameters for specific connections. Therefore this tool is also helpful
for direct transfers.

OPTIONS:

There's bash completion available for gtransfer. This supports completion of
options and URLs. URL completion also expands (remote) paths. Just hit the <TAB>
key to see what's possible.

The options are as follows:

[--source|-s sourceUrl] Determine the source URL for the transfer.

			Possible URL examples:

			{[gsi]ftp|http}://FQDN[:PORT]/path/to/file
			[file://]/path/to/file

			"FQDN" is the fully qualified domain name.

[--destination|-d destinationUrl]
			Determine the destination URL for the transfer.

			Possible URL examples:

			{[gsi]ftp}://FQDN[:PORT]/path/to/file
			[file://]/path/to/file

			"FQDN" is the fully qualified domain name.

[--transfer-list|-f transferList]
			As alternative to providing source and destination URLs
			on the commandline one can also provide a list of source
			and destination URLs. See the gt manual page for more
			details.

[--auto-optimize|-o transferMode]
			Activates automatic optimization of transfers
			depending on the size of files. The transferMode
			controls how files of different size classes are
			transferred. Currently only "seq[uential]" is possible.
			
[--recursive|-r]	Transfer files recursively.

[--verbose|-v]		Be verbose.

[--metric|-m dataPathMetric]
			Determine the metric to select the corresponding data
			path.

[--logfile|-l logfile]	Determine the name for the logfile, tgftp will generate
			for each transfer. If specified with ".log" as
			extension, gtransfer will insert a "__step_#" string to
			the name of the logfile ("#" is the number of the
			transfer step performed). If omitted gtransfer will
			automatically generate a name for the logfile(s).

[--auto-clean|-a]	Remove logfiles automatically after the transfer
			completed.

[--configfile configurationFile]
			Determine the name of the configuration file for
			gtransfer. If not set, this defaults to:

			"/etc/gtransfer/gtransfer.conf" or

			"<INSTALL_PATH>/etc/gtransfer.conf" or

			"/etc/opt/gtransfer/gtransfer.conf" or

			"$HOME/.gtransfer/gtransfer.conf" in this order.

[--guc-max-retries gucMaxRetries]
			Set the maximum number of retries globus-url-copy (guc)
			will do for a transfer of a single file. By default this
			is set to 1, which means that guc will tolerate at max.
			one transfer error per file and retry the transfer once.
			Alternatively this option can also be set through the
			environment variable "GUC_MAX_RETRIES".

[--gt-max-retries gtMaxRetries]
			Set the maximum number of retries gt will do for a
			single transfer step. By default this is set to 3, which
			means that gt will try to finish a single transfer step
			three times or fail. Alternatively this option can also
			be set through the environment variable
			"GT_MAX_RETRIES".

[--gt-progress-indicator indicatorCharacter]
			Set the character to use for the progress indicator of
			gtransfer. By default this is a ".".

[-- gsiftpParameters]	Determine the "globus-url-copy" parameters that should
			be used for all transfer steps. Notice the space between
			"--" and the actual parameters. This overwrites any
			available default parameters and is not recommended for
			regular usage. There exists one exception for "-len" or
			"-partial-length". If one of these is provided, it will
			only be added to the default parameters for a connection
			or - if no default parameters are available - to the
			builtin default parameters.

			NOTICE:
			If specified, this option must be the last one in a
			gtransfer command line.

--------------------------------------------------------------------------------

[--help]		Prints out a help message.

[--version|-V]		Prints out version information.

HELP

	return
}
#END_HELP#######################################################################


#VERSION########################################################################
versionMsg()
{
	echo "gtransfer - The GridFTP transfer script v$version"

        return
}
#END_VERSION####################################################################


echoDebug()
{
	local fd="$1"
	local debugLevel="$2"
	local debugString="$3"

	if [[ "$fd" == "stdout" ]]; then
		echo "$debugLevel: $debugString"
	elif [[ "$fd" == "stderr" ]]; then
		echo "$debugLevel: $debugString" 1>&2
	else
		echo "$debugLevel: $debugString" >$fd
	fi		

	return
}


onExit()
{
	#  on EXIT remove all temporary files (temporary files with the gt tmp
	#+ suffix are recreated at every run and hence can also be savely
	#+ removed on EXIT)
	set +f

	rm -rf ${__GLOBAL__gtTmpDir}/*."$__GLOBAL__gtTmpSuffix"

	return
}
################################################################################

################################################################################
#  MAIN
################################################################################

trap 'onExit' EXIT

#  check that all required tools are available
helperFunctions/use cat grep sed cut sleep tgftp telnet uberftp || exit "$_gtransfer_exit_software"

dataPathMetricSet="1"
tgftpLogfileNameSet="1"

#  Defaults
gtMaxRetries="3"
gucMaxRetries="1"
gtProgressIndicator="."
recursiveTransferSet=1

#  The temp dir is named after the SHA1 hash of the command line.
readonly __GLOBAL__gtTmpDirName=$( echo "$0 $@" | sha1sum | cut -d ' ' -f 1 )
readonly __GLOBAL__gtTmpDir="$HOME/.gtransfer/tmp/$__GLOBAL__gtTmpDirName"

#  correct number of params?
if [[ "$#" -lt "1" ]]; then
   # no, so output a usage message
   usageMsg
   exit $_gtransfer_exit_usage
fi

# read in all parameters
while [[ "$1" != "" ]]; do

	#  only valid params used?
	#
	#  NOTICE:
	#  This was added to prevent high speed loops
	#+ if parameters are mispositioned.
	if [[   "$1" != "--help" && \
		"$1" != "--version" && "$1" != "-V" && \
		"$1" != "--source" && "$1" != "-s" && \
		"$1" != "--destination" && "$1" != "-d" && \
		"$1" != "--metric" && "$1" != "-m" && \
		"$1" != "--verbose" && "$1" != "-v" && \
		"$1" != "--auto-clean" && "$1" != "-a" && \
		"$1" != "--logfile" && "$1" != "-l" && \
		"$1" != "--configfile" && \
                "$1" != "--guc-max-retries" && \
                "$1" != "--gt-max-retries" && \
                "$1" != "--transfer-list" && "$1" != "-f" && \
                "$1" != "--gt-progress-indicator" && \
                "$1" != "--auto-optimize" && "$1" != "-o" && \
                "$1" != "--recursive" && "$1" != "-r" && \
		"$1" != "--" \
	]]; then
		#  no, so output a usage message
		usageMsg
		exit $_gtransfer_exit_usage
	fi

	#  "--"
	if [[ "$1" == "--" ]]; then
		#  remove "--" from "$@"
		shift 1
		#  params forwarded to "globus-url-copy"
		gsiftpUserParams="$@"

		#  exit the loop (this assumes that everything left in "$@" is
		#+ a "globus-url-copy" param).		
		break

	#  "--help"
	elif [[ "$1" == "--help" ]]; then
		helpMsg
		exit $_gtransfer_exit_ok

	#  "--version|-V"
	elif [[ "$1" == "--version" || "$1" == "-V" ]]; then
		versionMsg
		exit $_gtransfer_exit_ok

	#  "--source|-s gsiftpSourceUrl"
	elif [[ "$1" == "--source" || "$1" == "-s" ]]; then
		if [[ "$gsiftpSourceUrlSet" != "0" ]]; then
			shift 1
			gsiftpSourceUrl="$1"
			gsiftpSourceUrlSet="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--source|-s\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

	#  "--destination|-d gsiftpDestinationUrl"
	elif [[ "$1" == "--destination" || "$1" == "-d" ]]; then
		if [[ "$gsiftpDestinationUrlSet" != "0" ]]; then
			shift 1
			gsiftpDestinationUrl="$1"
			gsiftpDestinationUrlSet="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--destination|-d\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

        #  "--transfer-list|-f transferList"
	elif [[ "$1" == "--transfer-list" || "$1" == "-f" ]]; then
		if [[ ! $gsiftpTransferListSet -eq 1 ]]; then
			shift 1
			gsiftpTransferList="$1"
			gsiftpTransferListSet=1
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--transfer-list|-f\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

	#  "--auto-optimize|-o transferMode"
	elif [[ "$1" == "--auto-optimize" || "$1" == "-o" ]]; then
		if [[ "$autoOptimizeSet" != "0" ]]; then
			shift 1
			transferMode="$1"
			autoOptimizeSet="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--auto-optimization|-o\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

        #  "--guc-max-retries gucMaxRetries"
	elif [[ "$1" == "--guc-max-retries" ]]; then
		if [[ "$gucMaxRetriesSet" != "0" ]]; then
			shift 1
			gucMaxRetries="$1"
			gucMaxRetriesSet="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--guc-max-retries\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

        #  "--gt-max-retries gtMaxRetries"
	elif [[ "$1" == "--gt-max-retries" ]]; then
		if [[ "$gtMaxRetriesSet" != "0" ]]; then
			shift 1
			gtMaxRetries="$1"
			gtMaxRetriesSet="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--gt-max-retries\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

        #  "--gt-progress-indicator indicatorCharacter"
        elif [[ "$1" == "--gt-progress-indicator" ]]; then
		if [[ "$gtProgressIndicatorSet" != "0" ]]; then
			shift 1
			gtProgressIndicator="$1"
			gtProgressIndicatorSet="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--gt-progress-indicator\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

	#  "--metric|-m dataPathMetric"
	elif [[ "$1" == "--metric" || "$1" == "-m" ]]; then
		if [[ "$dataPathMetricSet" != "0" ]]; then
			shift 1
			dataPathMetric="$1"
			dataPathMetricSet="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--metric|-m\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

	#  "--verbose|-v"
	elif [[ "$1" == "--verbose" || "$1" == "-v" ]]; then
		if [[ $verboseExecSet != 0 ]]; then
			shift 1
			verboseExecSet=0
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--verbose|-v\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi
		
	#  "--recursive|-r"
	elif [[ "$1" == "--recursive" || "$1" == "-r" ]]; then
		if [[ $recursiveTransferSet != 0 ]]; then
			shift 1
			recursiveTransferSet=0
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--recursive|-r\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

	#  "--auto-clean|-a"
	elif [[ "$1" == "--auto-clean" || "$1" == "-a" ]]; then
		if [[ $autoCleanSet != 0 ]]; then
			shift 1
			autoClean=0
			autoCleanSet=0
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--auto-clean|-a\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

	#  "--logfile|-l"
	elif [[ "$1" == "--logfile" || "$1" == "-l" ]]; then
		if [[ $tgftpLogfileNameSet != 0 ]]; then
			shift 1
			tgftpLogfileName="$1"
			tgftpLogfileNameSet=0
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--logfile|-l\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

	#  "--configfile"
	elif [[ "$1" == "--configfile" ]]; then
		if [[ $gtransferConfigurationFileSet != 0 ]]; then
			shift 1
			gtransferConfigurationFile="$1"
			gtransferConfigurationFileSet=0
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--configfile\" cannot be used multiple times!"
			exit $_gtransfer_exit_usage
		fi

	fi

done

#  load configuration file
if [[ -e "$gtransferConfigurationFile" ]]; then
	. "$gtransferConfigurationFile"
else
	echo "ERROR: gtransfer configuration file missing!"
	exit $_gtransfer_exit_software
fi

#  verbose execution needed due to options?
if [[ $verboseExecSet == 0 ]]; then
	verboseExec=1
fi

#  auto optimization requested?
if [[ $autoOptimizeSet == 0 ]]; then
	autoOptimize=1 # 1 on, 0 off
fi

#  set dpath metric
if [[ "$dataPathMetricSet" != "0" ]]; then
	dataPathMetric="$defaultDataPathMetric"
fi

#  set logfile name
if [[ "$tgftpLogfileNameSet" != "0" ]]; then
	tgftpLogfileName="$defaultTgftpLogfileName"
fi

#  all mandatory params present?
if [[ "$gsiftpSourceUrl" == "" || \
      "$gsiftpDestinationUrl" == "" \
]]; then
        if [[ $gsiftpTransferListSet -eq 1 ]]; then
		#  create directory for temp files
		mkdir -p "$__GLOBAL__gtTmpDir"
		
		#  strip comment lines from transfer list
		gsiftpTransferListClean="$__GLOBAL__gtTmpDir/$$_transferList.${__GLOBAL__gtTmpSuffix}"		
		sed -e '/^#.*$/d' "$gsiftpTransferList" > "$gsiftpTransferListClean"

		#  TODO:
		#  Use temporary dir for temp files (.gtransfer/<transferID>)
		#  1. Determine transfer id for original transfer list
		#  2. Create temp dir (e.g. _tempDir=$( echo "$0" "$@" | sha1sum )) and store path in global var
		if [[ $autoOptimize -eq 1 ]]; then
			#  only perform auto-optimization if there are at least
			#+ 100 files in the transfer list. If not perform simple
			#+ list transfer.
			if [[ $( listTransfer/getNumberOfFilesFromTransferList "$gsiftpTransferListClean" ) -ge 100 ]]; then
				autoOptimization/performTransfer "$gsiftpTransferListClean"  "$dataPathMetric" "$tgftpLogfileName" "$chunkConfig" "$transferMode"
			else
				listTransfer/performTransfer "$gsiftpTransferListClean" "$dataPathMetric" "$tgftpLogfileName"
			fi
		else
			listTransfer/performTransfer "$gsiftpTransferListClean" "$dataPathMetric" "$tgftpLogfileName"
		fi
	else
		#  no, so output a usage message
		usageMsg
		exit $_gtransfer_exit_usage
	fi
else
	#  create directory for temp files
	mkdir -p "$__GLOBAL__gtTmpDir"

	if [[ $autoOptimize -eq 1 ]]; then
		gsiftpTransferList=$( listTransfer/createTransferList "$gsiftpSourceUrl" "$gsiftpDestinationUrl" )
		#  only perform auto-optimization if there are at least
		#+ 100 files in the transfer list. If not perform simple
		#+ list transfer.
		if [[ $( listTransfer/getNumberOfFilesFromTransferList "$gsiftpTransferList" ) -ge 100 ]]; then
			autoOptimization/performTransfer "$gsiftpTransferList"  "$dataPathMetric" "$tgftpLogfileName" "$chunkConfig" "$transferMode"
		else
			rm "$gsiftpTransferList"
			urlTransfer/transferData "$gsiftpSourceUrl" "$gsiftpDestinationUrl" "$dataPathMetric" "$tgftpLogfileName"
		fi
	else
		urlTransfer/transferData "$gsiftpSourceUrl" "$gsiftpDestinationUrl" "$dataPathMetric" "$tgftpLogfileName"
	fi
fi

#transferData "$gsiftpSourceUrl" "$gsiftpDestinationUrl" "$dataPathMetric" "$tgftpLogfileName"
transferDataReturnValue="$?"

#  if transfer was successful, remove dir for temp files
if [[ $transferDataReturnValue -eq 0 ]]; then
	rm -rf "$__GLOBAL__gtTmpDir"
fi

#  automatically remove logfiles if needed
if [[ $autoClean == 0 ]]; then
	rm -rf ${tgftpLogfileName/%.log/}*
fi

exit $transferDataReturnValue

