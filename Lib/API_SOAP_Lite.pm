package Koha::Illbackends::RapidILL::Lib::API_SOAP_Lite;

use SOAP::Lite +trace => 'all';
use Data::Dumper;

sub new {
    my $class = shift;
    my $url = shift;
    my $credentials = shift;
    my $self = {
        url => $url,
        credentials => $credentials,
        _kohalogger => Koha::Logger->get({ category => $class })
    };
    return bless $self, $class;
}

sub call {
    my ($self, $operation, $request, $fieldmap) = @_;

    my $soap = SOAP::Lite->proxy($self->{url});

    my @params = ();

    my %stuff = ( %$request, %{$self->{credentials}} );

    while (my ($name, $value) = each %stuff) {
        $value =~ s/^\s*(.*?)\s*$/$1/;
        next if $value eq '';
        my $type = $fieldmap->{$name}->{type};
        if ($name eq 'RapidRequestType') {
            $type = "rapid5api:RequestType"
        }
        if (!defined $type) {
            if ($name eq "ClientAppName" || $name eq "PatronNotes") {
                $type = "string";
            } elsif ($name eq "UpdateAction") {
                $type = "rapid5api:ApiRequestUpdateAction";
            } elsif (exists $self->{credentials}->{$name}) {
                $type = "string";
            } else {
                $type = "boolean";
            }
        }
        if ($type eq "array") {
            my @a = map { SOAP::Data->name('rapid5api:string')->value($_)->type('string') } (split / +/, $value);
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
        $self->_log->error($msg);
        return {
          IsSuccess => 0,
          errormsg => msg
        };
    }

    if ($self->_is_debug) {
        $self->_debug("result: " . Dumper($resp->result));
    }

    my $result = $resp->result;

    $result->{IsSuccessful} = 0 if $result->{IsSuccessful} eq 'false';
    $result->{FoundMatch} = 0 if $result->{FoundMatch} eq 'false';
    $result->{IsLocalHolding} = 0 if $result->{IsLocalHolding} eq 'false';
    if (exists $result->{LocalHoldings} && exists $result->{LocalHoldings}->{LocalHoldingItem} && (ref $result->{LocalHoldings}->{LocalHoldingItem}) eq "HASH") {
        $result->{LocalHoldings}->{LocalHoldingItem} = [$result->{LocalHoldings}->{LocalHoldingItem}];
    }

    return $result;
 }

sub _log {
    my $self = shift;
    return $self->{_kohalogger};
}

sub _is_debug {
    my $self = shift;
    return $self->{_kohalogger}->is_debug;
}

sub _debug {
    my $self = shift;
    return $self->{_kohalogger}->debug(@_);
}

1;
