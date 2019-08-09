#!/lib/init/init-d-script
### BEGIN INIT INFO
# Provides:          graywing-qs
# Required-Start:    $syslog $time $remote_fs
# Required-Stop:     $syslog $time $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: run CrystalPool Query Service HTTP endpoint
# Description:       Debian init script to start the daemon
#                    that provides SPARQL HTTP endpoint and a query web app for CrystalPool,
#                    a Warriors knowledge base.
### END INIT INFO
NAME="$PWSH_PATH"
START_ARGS="--background"
PIDFILE="/var/run/crystalpool/daemon.pid"
DAEMON_ARGS="$GRAY_WING_DAEMON_PATH"
