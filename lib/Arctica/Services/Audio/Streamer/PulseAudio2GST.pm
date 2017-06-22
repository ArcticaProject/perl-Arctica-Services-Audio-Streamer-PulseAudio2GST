################################################################################
#          _____ _
#         |_   _| |_  ___
#           | | | ' \/ -_)
#           |_| |_||_\___|
#                   _   _             ____            _           _
#    / \   _ __ ___| |_(_) ___ __ _  |  _ \ _ __ ___ (_) ___  ___| |_
#   / _ \ | '__/ __| __| |/ __/ _` | | |_) | '__/ _ \| |/ _ \/ __| __|
#  / ___ \| | | (__| |_| | (_| (_| | |  __/| | | (_) | |  __/ (__| |_
# /_/   \_\_|  \___|\__|_|\___\__,_| |_|   |_|  \___// |\___|\___|\__|
#                                                  |__/
#          The Arctica Modular Remote Computing Framework
#
################################################################################
#
# Copyright (C) 2015-2016 The Arctica Project
# http://arctica-project.org/
#
# This code is dual licensed: strictly GPL-2 or AGPL-3+
#
# GPL-2
# -----
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc.,
#
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
#
# AGPL-3+
# -------
# This programm is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This programm is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Copyright (C) 2015-2016 Guangzhou Nianguan Electronics Technology Co.Ltd.
#                         <opensource@gznianguan.com>
# Copyright (C) 2015-2016 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
#
################################################################################
package Arctica::Services::Audio::Streamer::PulseAudio2GST;
use strict;
use Exporter qw(import);
use Arctica::Core::BugOUT::Basics qw( BugOUT );
use Arctica::Core::Mother::Forker;
use Data::Dumper;# Remove this before release! (unless we're still dependant)

# Be very selective about what (if any) gets exported by default:
our @EXPORT = qw( );
# And be mindfull of what we lett the caller request here too:
our @EXPORT_OK = qw( );

my $arctica_core_object;

sub new {
	BugOUT(9,"PulseAudio2GST new->ENTER");
	my $class_name = $_[0];# Be EXPLICIT!! DON'T SHIFT OR "@_";
	$arctica_core_object = $_[1];
	my $JBUS_Server = $_[2];
	my $self = {
		isArctica => 1, # Declare that this is a Arctica "something"
		aobject_name => "PulseAudio2GST",
		JBUS_Server => $JBUS_Server,
		_defaults => {
			output_bitrate => 64,
			input_bitrate => 32,
		},
	};

	bless($self, $class_name);





	$arctica_core_object->{'aobj'}{'AudioServer'}{'PulseAudio2GST'} = \$self;

	BugOUT(9,"PulseAudio2GST new->DONE");

	return $self;
}


sub start_output {
	BugOUT(9,"PulseAudio2GST start_output->ENTER");
	my $self = $_[0];
	my $id_num = $_[1];
	my $pa_dev = $_[2];
	BugOUT(8,"Starting OUTPUT:\tAIOD#$id_num\tPA: $pa_dev");
	if ($self->{'vdev'}{'output'}{$id_num}{'port'} and $self->{'_settings'}{'socket_type'}) {
		my $pa_dev_monitor = $pa_dev;
		unless ($pa_dev =~ /\.monitor$/) {
			$pa_dev_monitor = "$pa_dev.monitor";
			BugOUT(9,"Append '.monitor' to $pa_dev_monitor");
		}
		my $bitrate = $self->get_bitrate("output");
		$self->{'vdev'}{'output'}{$id_num}{'running'} = 1;
		$self->{'vdev'}{'output'}{$id_num}{'gst_thread'} = Arctica::Core::Mother::Forker->new($arctica_core_object,{
			child_name	=>	'thread_gst',
			fork_style	=>	'interactive_pty',
			handle_stdeoc	=>	sub {return 1;},
			return_stdin	=>	1,
			exec_hold	=>	0,
			exec_path	=>	"/audiotest/bin/launch_server_ThreadGST",# FIXME GET FULL PATH FROM CFG OR SOMETHING LIKE THAT
			exec_cl_argv	=>	[
							"-src=$self->{'_settings'}{'socket_type'}",
							"-port=$self->{'vdev'}{'output'}{$id_num}{'port'}",
							"-pa_device_name=$pa_dev_monitor",
							"-start_bitrate=$bitrate",
						],
		});
	} else {
		BugOUT(1,"PulseAudio2GST start_output port and socket type not set?!! WTF?!");
	}
	BugOUT(9,"PulseAudio2GST start_output->DONE");
}


sub stop_output {
	BugOUT(9,"PulseAudio2GST stop_output->ENTER");
	my $self = $_[0];
	my $id_num = $_[1];
	if ($self->{'vdev'}{'output'}{$id_num}{'gst_thread'}) {
		$self->{'vdev'}{'output'}{$id_num}{'gst_thread'}->send("cmd:stop:");
# FIXME FORCE DESTRUCTION OF Mother::Forker object here?
		$self->{'vdev'}{'output'}{$id_num}{'running'} = 0;
	}
	BugOUT(9,"PulseAudio2GST stop_output->DONE");
}


sub start_input {
	BugOUT(9,"PulseAudio2GST start_input->ENTER");
	my $self = $_[0];
	my $id_num = $_[1];
	my $pa_dev = $_[2];
	my $run_on_ready = $_[3];
	BugOUT(8,"Starting INPUT:\tAIOD#$id_num\tPA: $pa_dev");
	if ($self->{'vdev'}{'input'}{$id_num}{'port'} and $self->{'_settings'}{'socket_type'}) {
		$self->{'vdev'}{'input'}{$id_num}{'running'} = 1;
		$self->{'vdev'}{'input'}{$id_num}{'gst_thread'} = Arctica::Core::Mother::Forker->new($arctica_core_object,{
			child_name	=>	'thread_gst',
			fork_style	=>	'interactive_pty',
			handle_stdeoc	=>	sub {
					if ($_[0] =~ /^status:sink_ready:(\d{1,3}):$/) {
						$run_on_ready->($1);
					}
				},
			return_stdin	=>	1,
			exec_hold	=>	0,
			exec_path	=>	"/audiotest/bin/launch_server_ThreadGST",# FIXME GET FULL PATH FROM CFG OR SOMETHING LIKE THAT
			exec_cl_argv	=>	[
							"-snk=$self->{'_settings'}{'socket_type'}",
							"-port=$self->{'vdev'}{'input'}{$id_num}{'port'}",
							"-pa_device_name=$pa_dev",
						],
		});
	} else {
		BugOUT(1,"PulseAudio2GST start_input port and socket type not set?!! WTF?!");
	}
	BugOUT(9,"PulseAudio2GST start_input->DONE");
}


sub stop_input {
	BugOUT(9,"PulseAudio2GST stop_input->ENTER");
	my $self = $_[0];
	my $id_num = $_[1];
	if ($self->{'vdev'}{'input'}{$id_num}{'gst_thread'}) {
		$self->{'vdev'}{'input'}{$id_num}{'gst_thread'}->send("cmd:stop:");
# FIXME FORCE DESTRUCTION OF Mother::Forker object here?
		$self->{'vdev'}{'input'}{$id_num}{'running'} = 0;
	}
	BugOUT(9,"PulseAudio2GST stop_input->DONE");
}



sub thread_cmd {
	BugOUT(9,"PulseAudio2GST thread_cmd->ENTER");
	my $self = $_[0];
	my $type = $_[1];
	my $idnum= $_[2];
	my $cmd = $_[3];
	BugOUT(9,"$type\t$idnum\t$cmd\n");
	if ($self->{'vdev'}{$type}{$idnum}{'gst_thread'}) {
		BugOUT(9,"sTEP 2; $type\t$idnum\t$cmd\n");
		if ($cmd =~ /^([a-z]{1,10})$/) {
		BugOUT(9,"sTEP 3; $type\t$idnum\t$cmd\n");
			$self->{'vdev'}{$type}{$idnum}{'gst_thread'}->send("cmd:$1:");
			BugOUT(8,"PulseAudio2GST: thread_cmd: Sent '$1' to $type #$idnum");
		}
	}
	BugOUT(9,"PulseAudio2GST thread_cmd->DONE");
	return 1;
}



sub set_jbus_client_id {
	my $self = $_[0];
	$self->{'jbus_client_id'} = $_[1];
}


sub set_device_socket_type  {
	BugOUT(9,"PulseAudio2GST set_device_socket_type->ENTER");
	my $self = $_[0];

	if (($_[1] eq "tcp") or ($_[1] eq "unixs")) {
		$self->{'_settings'}{'socket_type'} = $_[1];
		$self->{'_settings'}{'com_style'} = "stream";
		BugOUT(9,"set_device_socket_type: socket type set to $_[1]/stream");
	} elsif (($_[1] eq "udp") or ($_[1] eq "unixd")) {
		$self->{'_settings'}{'socket_type'} = $_[1];
		$self->{'_settings'}{'com_style'} = "datagram";
		BugOUT(9,"set_device_socket_type: socket type set to $_[1]/datagram");
	} else {
		BugOUT(0,"set_device_socket_type: '$_[1]' is not a valid socket_type");
	}

	BugOUT(9,"PulseAudio2GST set_device_socket_type->DONE");
}



sub get_device_socket_type {
	my $self = $_[0];
	if ($self->{'_settings'}{'socket_type'} and $self->{'_settings'}{'com_style'}) {
		return ($self->{'_settings'}{'socket_type'},$self->{'_settings'}{'com_style'});
	} else {
		return (0,0);
	}
}


sub set_device_gst_port {
	BugOUT(9,"PulseAudio2GST set_device_gst_port->ENTER");
	my $self = $_[0];
	my $device = $_[1];
	my $port = $_[2];

	if ($device =~ /^o(\d{1,})/) {
		$self->{'vdev'}{'output'}{$1}{'port'} = $port;
		BugOUT(9,"set_device_gst_port: output:$1:$port");
	} elsif ($device =~ /^i(\d{1,})/) {
		$self->{'vdev'}{'input'}{$1}{'port'} = $port;
		BugOUT(9,"set_device_gst_port: input:$1:$port");
	} else {
		BugOUT(2,"set_device_gst_port: Failed to set device '$device' port to '$port'");
	}

	BugOUT(9,"PulseAudio2GST set_device_gst_port->DONE");
}


sub set_bitrate {
	BugOUT(9,"PulseAudio2GST set_bitrate->ENTER");
	my $self = $_[0];
	my $new_output_rate = 0;
	my $new_input_rate = 0;
# 	We only check that things are somewhat sane here... If we're above or bellow the accepted range, the closest supported range is used
#	Redundant sanity checks are good, but would like to avoid having redundant decission making... (decision is made in the GST thread).
	if ($_[1] =~ /^(\d{1,})\:(\d{1,})$/) {
		$new_output_rate = $1;
		$new_input_rate = $2;
		BugOUT(9,"Got asymetrical I/O BW ($1 : $2)");
	} elsif ($1 =~ /^(\d{1,})$/) {
		$new_output_rate = $1;
		$new_input_rate = $1;
		BugOUT(9,"Symetrical I/O BW? ($1)");
	} else {
		BugOUT(8,"Weird bitrate format... Using previously set or default BW...");
	}

	if (($new_output_rate > 0) and ($new_input_rate > 0)) {
		if (($new_output_rate > 1000) or($new_input_rate > 1000)) {
			BugOUT(1,"Bitrates0 ($new_output_rate : $new_input_rate) seem high, expecting KILO bit values so maybe knock of a few zeros?");
		}

		if ($self->{'_settings'}{'output_bitrate'} ne $new_output_rate) {
			$self->{'_settings'}{'output_bitrate'} = $new_output_rate;
			foreach my $idnum (keys %{$self->{'vdev'}{'output'}}) {

				if ($self->{'vdev'}{'output'}{$idnum}{'running'}) {
					if ($self->{'vdev'}{'output'}{$idnum}{'gst_thread'}) {
						$self->{'vdev'}{'output'}{$idnum}{'gst_thread'}->send("set:bitrate:$new_output_rate");
					}
				}

			}
			BugOUT(9,"Output bitrate set to $new_output_rate");
		} else {
			BugOUT(9,"Output bitrate is unchanged...");
		}

		if ($self->{'_settings'}{'input_bitrate'} ne $new_input_rate) {
			$self->{'_settings'}{'input_bitrate'} = $new_input_rate;
# FIXME Add function to brodcast rate change to "live" input threads
			BugOUT(9,"Input bitrate set to $new_input_rate");
		} else {
			BugOUT(9,"Input bitrate is unchanged...");
		}


	}
	BugOUT(9,"PulseAudio2GST set_bitrate->DONE");
}


sub get_bitrate {
	my $self = $_[0];
	if ($_[1] eq "output") {
		if ($self->{'_settings'}{'output_bitrate'}) {
			return $self->{'_settings'}{'output_bitrate'};
		} else {
			return $self->{'_defaults'}{'output_bitrate'};
		}
	} elsif ($_[1] eq "input") {
		if ($self->{'_settings'}{'input_bitrate'}) {
			return $self->{'_settings'}{'input_bitrate'};
		} else {
			return $self->{'_defaults'}{'input_bitrate'};
		}
	} else {
		BugOUT(2,"And you want bitrate for what? ($_[1])");
	}
}


sub get_active_client_id {
	my $self = $_[0];
	if ($self->{'jbus_client_id'}) {# FIXME Add stuff to chek if this client is still really truly active.
		return $self->{'jbus_client_id'};
	} else {
		return 0;
	}
}

1;

