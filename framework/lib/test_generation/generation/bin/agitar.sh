#!/bin/bash
#
# Template wrapper script for a test generation tool
#
# Exported environment variables:
# D4J_HOME:                The root directory of the used Defects4J installation.
# D4J_FILE_TARGET_CLASSES: File that lists all target classes (one per line).
# D4J_FILE_ALL_CLASSES:    File that lists all relevant classes (one per line).
# D4J_DIR_OUTPUT:          Directory to which the generated test suite sources
#                          should be written (may not exist).
# D4J_DIR_WORKDIR:         Defects4J working directory of the checked-out
#                          project version.
# D4J_DIR_TESTGEN_LIB:     Directory that provides the libraries of all
#                          testgeneration tools.
# D4J_CLASS_BUDGET:        The budget (in seconds) that the tool should spend at
#                          most per target class.
# D4J_SEED:                The random seed.

# General helper functions
source "$D4J_DIR_TESTGEN_LIB/bin/_tool.util"

AGITAR_UTILS="$D4J_DIR_TESTGEN_LIB/bin/agitar"

# ARX file
ARX="$D4J_DIR_WORKDIR/agitar.arx"

# Prepare Eclipse
#===================================
ECLIPSE_HOME="/mnt/c/Users/sina/Documents/GitHub/agitar-d4j-scripts/eclipse"

if [ "${ECLIPSE_HOME}" = "" ]; then
  echo  Please define ECLIPSE_HOME 
  exit 1
fi

case `uname -s` in
  SunOS) ECLIPSE_WINDOW_SYSTEM_FLAGS="-ws motif" ;;
  Linux) ECLIPSE_WINDOW_SYSTEM_FLAGS="-ws gtk" ;;
  *) ECLIPSE_WINDOW_SYSTEM_FLAGS="" ;;
esac

ECLIPSE_STARTUP_JAR=${ECLIPSE_HOME}/startup.jar

if [ ! -f "${ECLIPSE_STARTUP_JAR}" ]; then
  ECLIPSE_STARTUP_JAR=$(find "$ECLIPSE_HOME/plugins" -name "org.eclipse.equinox.launcher_*.jar" | sort | tail -1);

  if [ ! -f "${ECLIPSE_STARTUP_JAR}" ]; then
    echo  Can\'t find startup.jar in ECLIPSE_HOME or org.eclipse.equinox.launcher jar in ECLIPSE_HOME/plugins
    exit 1
  fi
fi

# D4J paths
#===================================

D4J_CP="$(get_project_cp)"
D4J_SRC="$(get_project_src)"
D4J_BIN="$(get_project_bin)"

# Prepare Agitar Environment
#===================================

if [ ! -f "$D4J_DIR_WORKDIR/.project" ]; then

   projfile=$(cat "$AGITAR_UTILS/template_eclipse_project")

   echo "$projfile" | sed "s/%%%NAME%%%/D4J/" > "$D4J_DIR_WORKDIR/.project"

fi

if [ ! -f "$D4J_DIR_WORKDIR/.classpath" ]; then

   classfile=$(cat "$AGITAR_UTILS/template_eclipse_classpath")

   LIBS=""
   for lib in $(echo $D4J_CP | sed "s/:/ /g"); do
     # call your procedure/other scripts here below
     l="<classpathentry kind=\"lib\" path=\"$lib\"/>"

     [[ $l =~ .*jar ]] && LIBS="$LIBS\n$l"
   done

   echo "$classfile" | sed "s@%%%SRC%%%@$D4J_SRC@g" | sed "s@%%%LIBS%%%@$LIBS@g" > "$D4J_DIR_WORKDIR/.classpath"

fi
#-- Prepare Agitar ARX
if [ ! -f "$ARX" ]; then

   arxfile=$(cat "$AGITAR_UTILS/template_agitar_arx")

   LIBS=""
   for lib in $(echo $D4J_CP | sed "s/:/ /g"); do
    # call your procedure/other scripts here below
     l="$lib"

     if [[ $l =~ .*jar ]]; then
#        [[ ! -z "$LIBS" ]] && LIBS="$LIBS;"
        LIBS="$LIBS$l;"
     fi
   done


   echo "$arxfile" | sed "s@%%%SRC%%%@$D4J_SRC@g" | sed "s@%%%CP%%%@$D4J_BIN@g" | sed "s@%%%LIBS%%%@$LIBS@g" | sed "s@%%%ECLIPSE%%%@$ECLIPSE_HOME@g" > "$ARX"

fi

#===================================
# Agitar base command
cmd_base="java -cp $ECLIPSE_STARTUP_JAR -ea -Xmx512m -Xms64m org.eclipse.core.launcher.Main -application com.agitar.eclipse.cmdline.RemoteGenerateTests $ECLIPSE_WINDOW_SYSTEM_FLAGS"

# The command that invokes the test generator
for class in $(cat $D4J_FILE_TARGET_CLASSES); do
    cmd="$cmd_base -p $ARX -testFolder $D4J_DIR_OUTPUT $class"

    # Print the command that failed, if an error occurred.
    if ! $cmd; then
        echo
        echo "FAILED: $cmd"
        exit 1
    fi
done
