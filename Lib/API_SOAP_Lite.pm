package Koha::Plugin::Com::PTFSEurope::RapidILL::Api_SOAP_Lite;

use SOAP::Lite;
require SOAP::Data;

sub new {
    my $class = shift;
    my $url = shift;
    my $credentials = shift;
    my $self = {
        url => $url,
        credentials => $credentials
    };
    return bless $self, $class;
}

sub call {
    my ($self, $operation, $request) = @_;

    my $soap = SOAP::Lite->proxy($self->{url});

    my @params = ();
    my $logger = Koha::Logger->get({ category => __PACKAGE__ });

    while (my ($name, $value) = each %$request) {
        push @params, SOAP::Data->name($name)->value($value);
    }

    my $response = $soap->call($operation, @params);

    if ($resp->fault) {
        my $detail = '';
        for my $k (keys %{$resp->faultdetail->{error}}) {
            $detail .= "$k: " . $resp->faultdetail->{error}->{$k} . "\n"
        }
        my $msg = $resp->faultcode . ' ' . $resp->faultstring . ":\n" . $detail;
        $logger->error($msg);
        return undef;
    }

    $logger->debug(Dumper($resp->result));

    return $resp->result;
 }
