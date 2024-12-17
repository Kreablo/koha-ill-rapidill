package Koha::Illbackends::RapidILL::Lib::API_XML_Compile;

use XML::Compile::WSDL11;

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

    open my $wsdl_fh, "<", dirname(__FILE__) . "/rapidill.wsdl" || die "Can't open file $!";
    my $wsdl_file = do { local $/; <$wsdl_fh> };
    my $wsdl = XML::Compile::WSDL11->new($wsdl_file);

    my $client = $wsdl->compileClient(
        operation => $operation,
        port      => "ApiServiceSoap12"
    );

    my $response = $client->($request);

}

1;
