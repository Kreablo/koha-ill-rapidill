package Koha::Illbackends::RapidILL::Lib::API_SOAP_Lite;

use SOAP::Lite +trace => 'all';

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
    my ($self, $operation, $request, $fieldmap) = @_;

    my $soap = SOAP::Lite->proxy($self->{url});

    my @params = ();
    my $logger = Koha::Logger->get({ category => __PACKAGE__ });

    my %stuff = ( %$request, %{$self->{credentials}} );

    while (my ($name, $value) = each %stuff) {
        $value =~ s/^\s*(.*?)\s*$/$1/;
        my $type = $fieldmap->{$name}->{type};
        if ($name eq 'RapidRequestType') {
            $type = "rapid5api:RequestType"
        }
        if (!defined $type) {
            if ($name eq "ClientAppName") {
                $type = "string";
            } elsif (exists $self->{credentials}->{$name}) {
                $type = "string";
            } else {
                $type = "boolean";
            }
        }
        if ($type eq "array") {
            my @a = map { SOAP::Data->value($value)->type('string') } (split / +/, $value);
            $value = \@a;
            $type = "rapid5api:ArrayOfString";
        }
        push @params, SOAP::Data->name('rapid5api:' . $name)->value($value)->type($type);
    }
    $soap->ns('http://rapid2.library.colostate.edu/rapid5api/', 'rapid5api');
    $soap->on_action( sub { join '', @_ } );
    my $input = SOAP::Data->name('rapid5api:input')->value(\@params);
    if ($operation eq 'InsertRequest') {
        $input = $input->type('rapid5api:InsertRequestInput_Api5');
    } elsif ($operation eq 'UpdateRequest') {
        $input = $input->type('rapid5api:UpdateRequestInput_Api5');
    }
    my $resp = $soap->call('rapid5api:' . $operation, $input);

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

1;
