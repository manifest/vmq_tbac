PROJECT = vmq_tbac
PROJECT_DESCRIPTION = VerneMQ Topic-Based Access Control (TBAC) Plugin
PROJECT_VERSION = 0.1.0

DEPS = \
	vmq_commons

dep_vmq_commons = git git://github.com/erlio/vmq_commons.git 0.9.4

SHELL_DEPS = tddreloader
SHELL_OPTS = \
	-eval 'application:ensure_all_started($(PROJECT), permanent)' \
	-s tddreloader start \
	-config rel/sys

include erlang.mk

PLUGIN_HOOKS= \
	[	{vmq_tbac, auth_on_register, 5, []}, \
		{vmq_tbac, auth_on_publish, 6, []}, \
		{vmq_tbac, auth_on_subscribe, 3, []} ]
app::
	perl -pi -e "s/(]}\.)/\t,{env, [{vmq_plugin_hooks, $(PLUGIN_HOOKS)}]}\n\1/" ebin/vmq_tbac.app
