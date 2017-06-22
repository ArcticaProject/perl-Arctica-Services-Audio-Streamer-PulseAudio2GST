use strict;
use ExtUtils::MakeMaker;

WriteMakefile (
  AUTHOR        => 'Arctica Project Developers',
  ABSTRACT      => "Arctica Service: Audio Streamer PulseAudio2GST",
  NAME          => 'Arctica::Services::Audio::Streamer::PulseAudio2GST',
  (eval { ExtUtils::MakeMaker->VERSION(6.21) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM     => {
    'Test::More' => '0.47',
  },
  VERSION_FROM  => 'lib/Arctica/Services/Audio/Streamer/PulseAudio2GST/Version.pm',
  clean               => { FILES => '' },
);
