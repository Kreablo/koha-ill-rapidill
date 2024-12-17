package Koha::Illbackends::RapidILL::Lib::Config;

use strict;

require Exporter;

use Koha::Config;
use YAML::Syck qw( LoadFile );
use File::Basename qw( dirname );

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(config);

use constant {
    CONFIG_FNAME => "rapidill-config.yaml"
};

sub config {
    my $conf_dir = dirname(Koha::Config->guess_koha_conf);

    my $config = LoadFile( $conf_dir . "/" . CONFIG_FNAME );

    return $config;
}

