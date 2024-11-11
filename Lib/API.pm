package Koha::Illbackends::RapidILL::Lib::API;

# Copyright PTFS Europe 2021
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request;
use JSON qw( encode_json );
use CGI;
use URI;
use File::Basename qw( dirname );
use YAML::Syck qw( LoadFile );

use Koha::Logger;
use C4::Context;
use Koha::Config;

use constant {
    CONFIG_FNAME => "rapidill-config.yaml",
    RAPIDILL_SERVICE_URL => "https://rapid.exlibrisgroup.com/rapid5api/apiservice.asmx?WSDL"
};

=head1 NAME

RapidILL - Client interface to RapidILL API plugin (koha-plugin-rapidill)

=cut

sub new {
    my ($class) = @_;

    my $self = {
    };

    bless $self, $class;
    return $self;
}

=head3 InsertRequest

Make a call to the RapidILL service api

=cut

sub InsertRequest {
    my ($self, $metadata, $borrowernumber) = @_;

    my $borrower = Koha::Patrons->find( $borrowernumber );

    my @name = grep { defined } ($borrower->firstname, $borrower->surname);

    $metadata = {
        PatronId             => $borrower->borrowernumber,
        PatronName           => join (" ", @name),
        IsHoldingsCheckOnly  => 0,
        DoBlockLocalOnly     => 0,
        %{$metadata}
    };

    $metadata->{PatronEmail} = $borrower->email if $borrower->email;

    my $input = {
        ClientAppName        => "Koha RapidILL client",
        %{$metadata}
    };

    return _instance()->call('InsertRequest', $input);
}

=head3 UpdateRequest

Make a call to the RapidILL service api

=cut

sub UpdateRequest {
    my ($self, $request_id, $action, $metadata) = @_;

    $metadata //= {};

    my $input =  {
        RapidRequestId       => $request_id,
        UpdateAction         => $action,
        %{$metadata}
    };

    return _instance()->call( 'UpdateRequest', $input );

}

sub _config {
    my $conf_dir = dirname(Koha::Config->guess_koha_conf);

    my $config = LoadFile( $conf_dir . "/" . CONFIG_FNAME );

    return $config;
}

sub _get_credentials {
    my $config = _config();


    if ($config && $config->{credentials}) {
        my $cred = $config->{credentials};

        return {
            UserName             => $cred->{username},
            Password             => $cred->{password},
            RequestingRapidCode  => $cred->{requesting_rapid_code},
            RequestingBranchName => $cred->{requesting_branch_name}
        };
    }

    die "No credentials configured!";
}

sub _class {
    my $name = shift;

    my $package = 'Koha::Illbackends::RapidILL::Lib::';

    if ($name eq 'XML::Compile') {
        return $package . 'API_XML_Compile';
    }

    if ($name eq 'SOAP::Lite') {
        return $package . 'Api_SOAP_Lite';
    }

    die "Unsupported class: '$name'";
}

sub _instance {
    my $config = _config();

    my $class = _class($config->{api_class} ?  $config->{api_class} : 'SOAP::Lite');

    return $class->new(RAPIDILL_SERVICE_URL, _get_credentials());
}


1;
