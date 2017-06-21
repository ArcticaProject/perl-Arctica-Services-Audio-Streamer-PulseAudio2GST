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
package Arctica::Services::Audio::Server::PulseAudio::ThreadGST_server;
use strict;
use Exporter qw(import);
use Arctica::Core::BugOUT::Basics qw( BugOUT );
#use Arctica::Core::Mother::Forker;
use IO::Handle;
use Time::HiRes qw( usleep );
use GStreamer1;
use Data::Dumper;# Remove this before release! (unless we're still dependant)

# Be very selective about what (if any) gets exported by default:
our @EXPORT = qw( );
# And be mindfull of what we lett the caller request here too:
our @EXPORT_OK = qw( );

my $ACO;

GStreamer1::init([ $0 ]);# Initiate GST


sub new {
	BugOUT(9,"ThreadGST new->ENTER");
	my $class_name = $_[0];# Be EXPLICIT!! DON'T SHIFT OR "@_";
	$ACO = $_[1];

	my $self = {
		isArctica => 1, # Declare that this is a Arctica "something"
		aobject_name => "ThreadGST",
		_default_out_rate => 64,# FIXME Look for defaults in a config file somewhere?
		_default_in_rate => 32,# FIXME	(We have a cfg file handler module somewhere.... Use it soon?)
		_default_pasuspender_fpath => "/usr/bin/pasuspender",# FIXME  ^^^^^^^^^^
	};
	bless($self, $class_name);

	if ($_[2]) {# FIXME!!!! We got some fancypants module somewhere that handles this.... switch to using that one, some day...!?
		foreach my $arg (@{$_[2]}) {
			BugOUT(8,"ARGY:\t$arg\t:ARG\n");
			if (($arg =~ /^\-(src)\=([a-z]{3,5})/) or ($arg =~ /^\-(snk)\=([a-z]{3,5})/) ){
	#			print "1:\t$1\n2:\t$2\n";
				if ($1 eq "src") {
					$self->_set_argv("src_or_snk","src");
				} elsif ($1 eq "snk") {
					$self->_set_argv("src_or_snk","snk");
				} else {
					BugOUT(9,"Not a server nor a client... what then...?");
				}
				if (($2 eq "tcp") or ($2 eq "unixs")) {
					$self->_set_argv("socket_type",$2);
					$self->_set_argv("com_style","stream");
				} elsif (($2 eq "udp") or ($2 eq "unixd")) {
					$self->_set_argv("socket_type",$2);
					$self->_set_argv("com_style","datagram");
				} else {
					BugOUT(0,"We can't be a '$2' $self->{'s_or_c'}");
				}

			} elsif ($arg =~ /^\-oo_([a-z]{2,10})\=([a-z0-9]*)/) {
				$self->_set_argv("opus_$1",$2);
			} elsif ($arg =~ /^\-port\=([a-z0-9]*)/) {
				$self->_set_argv("port_or_unix-socket",$1);
			} elsif ($arg =~ /^\-pa_device_name\=([a-zA-Z0-9\.\_\-]*)/) {
				BugOUT(8,"pa_device_name", $1);
				$self->_set_argv("pa_device_name", $1);
			} elsif ($arg =~ /^\-clientside\=([a-z]*)/) {
				if ($1 eq "pulseaudio") {
					$self->_set_argv("clientside","pulseaudio");
				} else {
					if ($1 ne "autoaudio") {
						BugOUT(1,"-clientside=$1 ? wtf? So we're going to try to use autoaudio...");
					}
					$self->_set_argv("clientside","autoaudio");
				}

			} elsif ($arg =~ /^\-wait\=1/) {
				$self->_set_argv("wait",1);
			} elsif ($arg =~ /^\-start_bitrate\=(\d{1,3})/) {
				$self->_set_argv("bitrate",$1);
			}
		}

	} else {
		BugOUT(0,"NO ARGS?");
	}

	$ACO->{'aobj'}{'ThreadGST'} = \$self;

	BugOUT(9,"ThreadGST new->DONE");
	return $self;
}


sub ch_options {
	my $self = $_[0];
	my $o_name = $_[1];
	my $o_value = $_[2];
	if ($o_name eq "bitrate") {
		if ($o_value =~ /^(\d{1,})$/) {
			$self->_tune_gstpipe($1);
		}
	} else {
		BugOUT(2,"WTF '$o_name'?");
	}
}

sub _set_argv {
	my $self = $_[0];
	my $arg_name = $_[1];
	my $arg_value = $_[2];
	# FIXME DO A BUNCH OF SANETIZING HERE?!
	$self->{'_argv'}{$arg_name} = $arg_value;
}

sub _get_argv {
	my $self = $_[0];
	my $arg_name = $_[1];
	if ($self->{'_argv'}{$arg_name}) {
		return $self->{'_argv'}{$arg_name};
	} else {
		return 0;
	}
}


sub _tune_gstpipe {
	my $self = $_[0];
	my $bitrate = $_[1];

	if ($self->{'main'}{'elements'}{'opusenc'}) {
		my $opusenc_element = $self->{'main'}{'elements'}{'opusenc'};
		$bitrate =~ s/\D//g;
		if ($bitrate  > 384) {
			$bitrate = 384;
		} elsif ($bitrate  < 4) {
			$bitrate = 4;
		}
		$opusenc_element->set("bitrate" => ($bitrate * 1000));
		BugOUT(1,"\t\tTWEAK IT:\t$bitrate");
		$opusenc_element->set("inband-fec" => 1);
		$opusenc_element->set("max-payload-size" => 200);
		$opusenc_element->set("frame-size" => 20);
		#FIXME INSERT MORE COMPLEX PERFORMANCE TUNING MATRIX STUFF HERE!
	}
}

sub _start_gstsrc {
	my $self = $_[0];
	# Cleanup stuff for collecting garbage from serverside pulseaudio
	$self->{'garbage'}{'pipeline'} = GStreamer1::Pipeline->new('garbagepipe');
	$self->{'garbage'}{'elements'}{'pasrc'} = GStreamer1::ElementFactory::make( pulsesrc => 'garbage_pasrc' );

	if ($self->_get_argv("pa_device_name")) {
		my $device_name = $self->_get_argv("pa_device_name");
		BugOUT(8,"PA_DEVICE_NAME: $device_name");
		$self->{'garbage'}{'elements'}{'pasrc'}->set('device' => $device_name);# 'arctica.output0.monitor'

	} else {
		BugOUT(8,"PA_DEVICE_NAME: USING DEFAULT DEVICE");
	}

	$self->{'garbage'}{'elements'}{'pasrc'}->set('client-name' => 'Arctica Garbage Collector');
	$self->{'garbage'}{'elements'}{'sink'} = GStreamer1::ElementFactory::make( fakesink => 'garbage_sink' );
	$self->{'garbage'}{'pipeline'}->add($self->{'garbage'}{'elements'}{'pasrc'});
	$self->{'garbage'}{'pipeline'}->add($self->{'garbage'}{'elements'}{'sink'});
	$self->{'garbage'}{'elements'}{'pasrc'}->link($self->{'garbage'}{'elements'}{'sink'});
	$self->{'garbage'}{'pipeline'}->set_state( "playing" );
	BugOUT(8,"Garbage collection initiated");

	my $pasuspender_fpath = $self->{'_default_pasuspender_fpath'};# FIXME FIX THIS AFTER CFG FILES HAVE BEEN PROPERLY IMPLEMENTED

	if (-X $pasuspender_fpath) {
		BugOUT(9,"pasuspender full path: $pasuspender_fpath");
		my $tpath = $ENV{'PATH'};
		$ENV{'PATH'} = "/bin:/usr/bin";
		system($pasuspender_fpath,"true");# FIXME Use Mother::Forker::Light.
		$ENV{'PATH'} = $tpath;
	} else {
		BugOUT(1,"NO pasuspender at full path: $pasuspender_fpath");# Not super critical but some audible junk may occur...
	}



	$self->{'main'}{'pipeline'} = GStreamer1::Pipeline->new('pipeline');

	$self->{'main'}{'elements'}{'queue1'} = GStreamer1::ElementFactory::make( queue => 'queue1' );
	$self->{'main'}{'elements'}{'queue1'}->set("silent" => 0);
	$self->{'main'}{'elements'}{'queue1'}->set("leaky" => "downstream");
	$self->{'main'}{'elements'}{'queue1'}->set("max-size-time" => "30000000");
	$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'queue1'});


	$self->{'main'}{'elements'}{'pasrc'} = GStreamer1::ElementFactory::make( pulsesrc => 'pasrc' );

	if ($self->_get_argv("pa_device_name")) {
		$self->{'main'}{'elements'}{'pasrc'}->set('device' => $self->_get_argv("pa_device_name"));# 'arctica.output0.monitor'
	}

	$self->{'main'}{'elements'}{'pasrc'}->set('client-name' => 'Arctica Audio Services');

	$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'pasrc'});
	$self->{'main'}{'elements'}{'pasrc'}->link($self->{'main'}{'elements'}{'queue1'});


	$self->{'main'}{'elements'}{'opusenc'} = GStreamer1::ElementFactory::make( opusenc  => 'opusenc' );
	$self->_tune_gstpipe($self->_get_argv("bitrate"));
	$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'opusenc'});
	$self->{'main'}{'elements'}{'queue1'}->link($self->{'main'}{'elements'}{'opusenc'});

	if ($self->_get_argv("com_style") eq "datagram")  {

		$self->{'main'}{'elements'}{'rtpopuspay'} = GStreamer1::ElementFactory::make( rtpopuspay => 'rtpopuspay' );
		$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'rtpopuspay'});
		$self->{'main'}{'elements'}{'opusenc'}->link($self->{'main'}{'elements'}{'rtpopuspay'});

		if ($self->_get_argv("socket_type") eq "udp") {

			$self->{'main'}{'elements'}{'udpsink'} = GStreamer1::ElementFactory::make( udpsink => 'udpsink' );
			$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'udpsink'});
			$self->{'main'}{'elements'}{'rtpopuspay'}->link($self->{'main'}{'elements'}{'udpsink'});

			$self->{'main'}{'elements'}{'udpsink'}->set('port' =>  $self->_get_argv("port_or_unix-socket"));
			$self->{'main'}{'elements'}{'udpsink'}->set('host' =>  'localhost');

		} elsif ($self->_get_argv("socket_type") eq "unixd") {
			BugOUT(0,"NOT YET IMPLEMENTED!");
		} else {
			BugOUT(0,"This should never happen!");
		}

	} elsif ($self->_get_argv("com_style") eq "stream")  {

		$self->{'main'}{'elements'}{'gdppay'} = GStreamer1::ElementFactory::make( gdppay => 'gdppay' );
		$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'gdppay'});
		$self->{'main'}{'elements'}{'opusenc'}->link($self->{'main'}{'elements'}{'gdppay'});

		$self->{'main'}{'elements'}{'queue2'} = GStreamer1::ElementFactory::make( queue => 'queue2' );
		$self->{'main'}{'elements'}{'queue2'}->set("silent" => 0);
		$self->{'main'}{'elements'}{'queue2'}->set("leaky" => "downstream");
		$self->{'main'}{'elements'}{'queue2'}->set("max-size-time" => "30000000");
		$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'queue2'});

		$self->{'main'}{'elements'}{'gdppay'}->link($self->{'main'}{'elements'}{'queue2'});

		if ($self->_get_argv("socket_type")  eq "tcp") {
			$self->{'main'}{'elements'}{'tcpclientsink'} = GStreamer1::ElementFactory::make( tcpclientsink => 'tcpclientsink' );
			$self->{'main'}{'elements'}{'tcpclientsink'}->set('port' =>  $self->_get_argv("port_or_unix-socket"));
			$self->{'main'}{'elements'}{'tcpclientsink'}->set('host' =>  'localhost');
			$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'tcpclientsink'});
			$self->{'main'}{'elements'}{'queue2'}->link($self->{'main'}{'elements'}{'tcpclientsink'});

		} elsif ($self->_get_argv("socket_type")  eq "unixs") {
			BugOUT(0,"NOT YET IMPLEMENTED!");
		} else {
			BugOUT(0,"This should never happen!");
		}

	} else {
		BugOUT(0,"com_style missing? WTF this should never happen at this point!");
	}


	usleep(5000);
	$self->{'main'}{'pipeline'}->set_state("paused");
	usleep(1000);
	$self->{'main'}{'pipeline'}->set_state("playing");
	BugOUT(8,"Main pipeline initiated");
	usleep(100000);
	$self->{'garbage'}{'pipeline'}->set_state("paused");
	$self->{'garbage'}{'pipeline'}->set_state("null");
	BugOUT(8,"Garbage collection done.");

}



sub _start_gstsnk {
	BugOUT(9,"ThreadGST _start_gstsnk->ENTER");
	my $self = $_[0];
##############################
#
	$self->{'garbage'}{'pipeline'} = GStreamer1::Pipeline->new('garbagepipe');
	$self->{'garbage'}{'elements'}{'pasrc'} = GStreamer1::ElementFactory::make( pulsesrc => 'garbage_pasrc' );

#		if ($self->_get_argv("pa_device_name")) {

		my $device_name = $self->_get_argv("pa_device_name");
		BugOUT(8,"PA_DEVICE_NAME: $device_name");
		print "INPUT: PA_DEVICE_NAME: $device_name";
		$self->{'garbage'}{'elements'}{'pasrc'}->set('device' => "arctica.mic0");# 'arctica.output0.monitor'

#		} else {
#			BugOUT(8,"PA_DEVICE_NAME: USING DEFAULT DEVICE");
#		}

	$self->{'garbage'}{'elements'}{'pasrc'}->set('client-name' => 'Arctica Garbage Collector');
	$self->{'garbage'}{'elements'}{'sink'} = GStreamer1::ElementFactory::make( fakesink => 'garbage_sink' );
	$self->{'garbage'}{'pipeline'}->add($self->{'garbage'}{'elements'}{'pasrc'});
	$self->{'garbage'}{'pipeline'}->add($self->{'garbage'}{'elements'}{'sink'});
	$self->{'garbage'}{'elements'}{'pasrc'}->link($self->{'garbage'}{'elements'}{'sink'});
	$self->{'garbage'}{'pipeline'}->set_state( "playing" );
	BugOUT(8,"Garbage collection initiated");
	my $pasuspender_fpath = $self->{'_default_pasuspender_fpath'};# FIXME FIX THIS AFTER CFG FILES HAVE BEEN PROPERLY IMPLEMENTED

	if (-X $pasuspender_fpath) {
		BugOUT(9,"pasuspender full path: $pasuspender_fpath");
		my $tpath = $ENV{'PATH'};
		$ENV{'PATH'} = "/bin:/usr/bin";
		system($pasuspender_fpath,"true");# FIXME Use Mother::Forker::Light.
		$ENV{'PATH'} = $tpath;
	} else {
		BugOUT(1,"NO pasuspender at full path: $pasuspender_fpath");# Not super critical but some audible junk may occur...
	}
#
##############################
	$self->{'main'}{'pipeline'} = GStreamer1::Pipeline->new('pipeline');

	$self->{'main'}{'elements'}{'opusdec'} = GStreamer1::ElementFactory::make( opusdec => 'opusdec' );
	$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'opusdec'});

	if ($self->_get_argv("com_style") eq "datagram")  {
		if ($self->_get_argv("socket_type") eq "udp") {

			$self->{'main'}{'elements'}{'udpsrc'} = GStreamer1::ElementFactory::make( udpsrc => 'udpsrc' );
			$self->{'main'}{'elements'}{'udpsrc'}->set('port' =>  $self->_get_argv("port_or_unix-socket"));
			$self->{'main'}{'elements'}{'udpsrc'}->set( caps => GStreamer1::Caps::Simple->new(
										'application/x-rtp',
										'media' =>  'Glib::String' => 'audio',
										'clock-rate' =>  'Glib::Int' => 48000,
										'encoding-name' =>  'Glib::String' => 'X-GST-OPUS-DRAFT-SPITTKA-00'));

			$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'udpsrc'});

			$self->{'main'}{'elements'}{'rtpopusdepay'} = GStreamer1::ElementFactory::make( rtpopusdepay => 'rtpopusdepay' );
			$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'rtpopusdepay'});

			$self->{'main'}{'elements'}{'udpsrc'}->link($self->{'main'}{'elements'}{'rtpopusdepay'});
			$self->{'main'}{'elements'}{'rtpopusdepay'}->link($self->{'main'}{'elements'}{'opusdec'});

		} elsif ($self->_get_argv("socket_type") eq "unixd") {
			BugOUT(0,"NOT YET IMPLEMENTED!");
		} else {
			BugOUT(0,"This should never happen!");
		}
	} elsif ($self->_get_argv("com_style") eq "stream")  {
		if ($self->_get_argv("socket_type")  eq "tcp") {

			$self->{'main'}{'elements'}{'tcpserversrc'} = GStreamer1::ElementFactory::make( tcpserversrc => 'tcpserversrc' );
			$self->{'main'}{'elements'}{'tcpserversrc'}->set('port' =>  $self->_get_argv("port_or_unix-socket"));
			$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'tcpserversrc'});

			$self->{'main'}{'elements'}{'queue1'} = GStreamer1::ElementFactory::make( queue => 'queue1' );
			$self->{'main'}{'elements'}{'queue1'}->set("silent" => 0);
			$self->{'main'}{'elements'}{'queue1'}->set("leaky" => "downstream");
			$self->{'main'}{'elements'}{'queue1'}->set("max-size-time" => "30000000");
			$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'queue1'});

			$self->{'main'}{'elements'}{'tcpserversrc'}->link($self->{'main'}{'elements'}{'queue1'});

			$self->{'main'}{'elements'}{'gdpdepay'} = GStreamer1::ElementFactory::make( gdpdepay => 'gdpdepay' );
			$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'gdpdepay'});

			$self->{'main'}{'elements'}{'queue1'}->link($self->{'main'}{'elements'}{'gdpdepay'});
			$self->{'main'}{'elements'}{'gdpdepay'}->link($self->{'main'}{'elements'}{'opusdec'});

		} elsif ($self->_get_argv("socket_type")  eq "unixs") {
			BugOUT(0,"NOT YET IMPLEMENTED!");
		} else {
			BugOUT(0,"This should never happen!");
		}
	}



	$self->{'main'}{'elements'}{'pasink'} = GStreamer1::ElementFactory::make( pulsesink => 'pasink' );

#	if ($self->_get_argv("pa_device_name")) {
#		$self->{'main'}{'elements'}{'pasink'}->set('device' => $self->_get_argv("pa_device_name"));
#	}

	$self->{'main'}{'elements'}{'pasink'}->set('device' =>  "arctica.input0");

	$self->{'main'}{'elements'}{'pasink'}->set('client-name' => 'Arctica Audio Services');

	$self->{'main'}{'pipeline'}->add($self->{'main'}{'elements'}{'pasink'});
	$self->{'main'}{'elements'}{'opusdec'}->link($self->{'main'}{'elements'}{'pasink'});

	usleep(10000);
	$self->{'main'}{'pipeline'}->set_state("playing");
	BugOUT(8,"Main pipeline initiated");
	print "status:sink_ready:",$self->_get_argv("idnum"),":\n";
	usleep(100000);
	$self->{'garbage'}{'pipeline'}->set_state( "paused" );
	$self->{'garbage'}{'pipeline'}->set_state( "null" );

	BugOUT(9,"ThreadGST _start_gstsnk->DONE");
}

sub start {
	my $self = $_[0];
	if ($self->_get_argv("src_or_snk") eq "src") {
		$self->_start_gstsrc;
	} elsif ($self->_get_argv("src_or_snk") eq "snk") {
		$self->_start_gstsnk;
	} else {
		BugOUT(0,"WTF? (src_or_snk!!)")
	}
}

sub terminate {
	my $self = $_[0];
	if ($self->{'main'}{'pipeline'}) {
		$self->{'main'}{'pipeline'}->set_state("paused");
		$self->{'main'}{'pipeline'}->set_state("null");
	}
	# FIXME! Do something else too??
}

1;

