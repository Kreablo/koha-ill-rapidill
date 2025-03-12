package Koha::Illbackends::RapidILL::Base;

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

use Modern::Perl;
use strict;
use warnings;
use CGI;

use JSON qw( to_json from_json );
use File::Basename qw( dirname );
use C4::Installer;

use Koha::Illbackends::RapidILL::Lib::API;
use Koha::Illbackends::RapidILL::Processor::SendArticleLink;
use Koha::ILL::Request::SupplierUpdate;
use Koha::Libraries;
use Koha::Patrons;
use Koha::Logger;
use C4::Languages;
use C4::Context;
use Koha::Illbackends::RapidILL::Lib::Config qw( config );
use Data::Dumper;
use utf8;

our $VERSION = "1.0.0";

use constant {
    LOCALLY_AVAILABLE => 'locally-available',
    GIVEN_BY_RAPIDILL => 'given-by-rapidill'
};

sub new {
    my ($class, $params) = @_;

    my $self = {
        _config => config(),
        _kohalogger => Koha::Logger->get({ category => $class })
    };

    $self->{_logger} = $params->{logger} if ( $params->{logger} );
    $self->{templates} = {
        'RAPIDILL_REQUEST_FAILED'    => dirname(__FILE__) . '/intra-includes/log/rapidill_request_failed.tt',
        'RAPIDILL_REQUEST_SUCCEEDED' => dirname(__FILE__) . '/intra-includes/log/rapidill_request_succeeded.tt'
    };

    $self->{processors} = [
        Koha::Illbackends::RapidILL::Processor::SendArticleLink->new
    ];

    bless($self, $class);

    $self->{_api} = Koha::Illbackends::RapidILL::Lib::API->new($VERSION, $self->fieldmap);

    return $self;
}

=head3 create

Handle the "create" flow

=cut

sub create {
    my ($self, $params) = @_;


    if ($self->_is_debug) {
        $self->_debug("RapidILL::create:" . Dumper($params));
    }

    my $other = $params->{other};
    my $stage = $other->{stage};

    my $lang = C4::Languages::getlanguage();
    my @lang_split = split /_|-/, $lang;

    my $response = {
        cwd            => dirname(__FILE__),
        backend        => $self->name,
        method         => "create",
        stage          => $stage,
        branchcode     => $other->{branchcode},
        cardnumber     => $other->{cardnumber},
        status         => "",
        message        => "",
        error          => 0,
        validation_group_sizes => $self->_validation_group_sizes,
        field_map      => $self->fieldmap_sorted,
        field_map_json => to_json($self->fieldmap()),
        lang_dialect   => $lang,
        lang_all       => $lang_split[0],
        rapidill_config => $self->{_config},
    };

    # Check for borrowernumber, but only if we're not receiving an OpenURL
    if (
        !$other->{openurl} &&
        (!$other->{borrowernumber} && defined( $other->{cardnumber} ))
    ) {
        $response->{cardnumber} = $other->{cardnumber};

        # 'cardnumber' here could also be a surname (or in the case of
        # search it will be a borrowernumber).
        my ( $brw_count, $brw ) =
          _validate_borrower( $other->{'cardnumber'}, $stage );

        if ( $brw_count == 0 ) {
            $response->{status} = "invalid_borrower";
            $response->{value}  = $params;
            $response->{stage} = "init";
            $response->{error}  = 1;
            return $response;
        }
        elsif ( $brw_count > 1 ) {
            # We must select a specific borrower out of our options.
            $params->{brw}     = $brw;
            $response->{value} = $params;
            $response->{stage} = "borrowers";
            $response->{error} = 0;
            return $response;
        }
        else {
            $other->{borrowernumber} = $brw->borrowernumber;
        }

        $self->{borrower} = $brw;
    }

    # Initiate process
    if ( !$stage || $stage eq 'init' ) {

        # First thing we want to do, is check if we're receiving
        # an OpenURL and transform it into something we can
        # understand
        if ($other->{openurl}) {
            # We only want to transform once
            delete $other->{openurl};
            $params = _openurl_to_ill($params);
        }

        # Pass the map of form fields in forms that can be used by TT
        # and JS
        $response->{field_map} = $self->fieldmap_sorted;
        $response->{field_map_json} = to_json($self->fieldmap());
        # We just need to request the snippet that builds the Creation
        # interface.
        $response->{stage} = 'init';
        $response->{value} = $params;
        return $response;
    }
    # Validate form and perform search if valid
    elsif ( $stage eq 'validate' || $stage eq 'form' ) {

        my $group_validity = $self->_validate_metadata($other);
        my $all_valid = (grep {!$_} (values %$group_validity)) == 0 ;

        if ($self->_is_debug) {
            $self->_debug("group_validity: " . Dumper($group_validity));
            $self->_debug("all_valid: $all_valid");
        }

        if ( _fail( $other->{'branchcode'} ) ) {
            # Pass the map of form fields in forms that can be used by TT
            # and JS
            $response->{field_map} = $self->fieldmap_sorted;
            $response->{field_map_json} = to_json($self->fieldmap());
            $response->{status} = "missing_branch";
            $response->{error}  = 1;
            $response->{stage}  = 'init';
            $response->{value}  = $params;
            $response->{group_validity} = $group_validity;
            return $response;
        }
        elsif ( !Koha::Libraries->find( $other->{'branchcode'} ) ) {
            # Pass the map of form fields in forms that can be used by TT
            # and JS
            $response->{field_map} = $self->fieldmap_sorted;
            $response->{field_map_json} = to_json($self->fieldmap());
            $response->{status} = "invalid_branch";
            $response->{error}  = 1;
            $response->{stage}  = 'init';
            $response->{value}  = $params;
            $response->{group_validity} = $group_validity;
            return $response;
        }
        elsif ( !$all_valid ) {

            if ($other->{opac}) {
                $response->{field_map} = $self->fieldmap_sorted;
                $response->{field_map_json} = to_json($self->fieldmap());
                $response->{status} = "invalid_metadata";
                $response->{error}  = 1;
                $response->{stage}  = 'init';
                $response->{value}  = $params;
                $response->{group_validity} = $group_validity;
                return $response;
            } else {

                # We don't have sufficient metadata for request creation,
                # create a local submission for later attention
                $self->create_submission($params);

                $response->{stage} = "commit";
                $response->{next} = "illview";
                return $response;
            }
        }
        else {
            if (C4::Context->preference('ILLCheckAvailability')) {
                my $requestability = $self->_check_requestability($params->{other});
                if ($self->_is_debug) {
                    $self->_debug("requestability: " . Dumper($requestability));
                }
                if (!$requestability->{requestable}) {
                    $response->{field_map} = $self->fieldmap_sorted;
                    $response->{field_map_json} = to_json($self->fieldmap());
                    $response->{status} = "not_requestable";
                    $response->{error}  = 1;
                    $response->{stage}  = 'init';
                    $response->{value}  = $params;
                    $response->{rapidill_reason} = $requestability->{reason};
                    $response->{rapidill_note} = $requestability->{note} if exists $requestability->{note};
                    $response->{rapidill_holdings} = $requestability->{holdings} if exists $requestability->{holdings};
                    $response->{group_validity} = $group_validity;
                    return $response;
                }
            }

            # We can submit a request directly to RapidILL
            my $result = $self->submit_and_request($params);

            if ($result->{success}) {
                $response->{stage}  = "commit";
                $response->{next} = "illview";
                $response->{params} = $params;
            } else {
                $response->{error}  = 1;
                $response->{stage}  = 'commit';
                $response->{next} = "illview";
                $response->{params} = $params;
                $response->{message} = $result->{message};
            }

            return $response;
        }
    }
}

=head3 cancel

   Attempt to cancel a request with Rapid 

=cut

sub cancel {
    my ($self, $params) = @_;

    # Update the submission's status
    $params->{request}->status("CANCREQ")->store;

    # Find the submission's Rapid ID
    my $rapid_request_id = $params->{request}->extended_attributes->find({
        illrequest_id => $params->{request}->illrequest_id,
        type          => "RapidRequestId"
    });

    if (!$rapid_request_id) {
        # No Rapid request, we don't need to do anything else
        return { success => 1 };
    }

    # This submission was submitted to Rapid, so we can try to cancel it there
    my $result = $self->{_api}->UpdateRequest(
        $rapid_request_id->value,
        "Cancel"
    );

    # If the cancellation was successful, note that in Staff notes
    if ($result->{IsSuccessful}) {
        $params->{request}->append_to_note("Cancelled with RapidILL");
        return {
            cwd    => dirname(__FILE__),
            method => "cancel",
            stage  => "commit",
            next   => "illview"
        };
    }
    # The call to RapidILL failed for some reason. Add the message we got back from the API
    # to the submission's Staff Notes
    $params->{request}->append_to_note("RapidILL request cancellation failed:\n" . $result->{VerificationNote});
    # Return the message
    return {
        cwd     => dirname(__FILE__),
        method  => "cancel",
        stage   => "init",
        error   => 1,
        message => $result->{VerificationNote}
    };
}

=head3 illview

   View and manage an ILL request

=cut

sub illview {
    my ($params) = @_;

    my $lang = C4::Languages::getlanguage();
    my @lang_split = split /_|-/, $lang;

    my $request = $params->{request};
    my $rapid_request_id = $params->{request}->extended_attributes->find({
        illrequest_id => $params->{request}->illrequest_id,
        type          => "RapidRequestId"
    });

    my $request_info;

    if (defined $rapid_request_id) {
        my $api = Koha::Illbackends::RapidILL::Lib::API->new($VERSION, {});
        $request_info = $api->RetrieveRequestInfo($rapid_request_id->value);
    }

    return {
        cwd    => dirname(__FILE__),
        lang_dialect   => $lang,
        lang_all       => $lang_split[0],
        request_info   => $request_info,
        method         => "illview"
    };
}

=head3 edititem

Edit an item's metadata

=cut

sub edititem {
    my ($self, $params) = @_;

    my $lang = C4::Languages::getlanguage();
    my @lang_split = split /_|-/, $lang;

    # Don't allow editing of requested submissions
    return {
        cwd    => dirname(__FILE__),
        method => 'illlist',
        lang_dialect   => $lang,
        lang_all       => $lang_split[0]
    } if $params->{request}->status ne 'NEW';

    my $other = $params->{other};
    my $stage = $other->{stage};
    if ( !$stage || $stage eq 'init' ) {
        my $attrs = $params->{request}->extended_attributes->unblessed;
        foreach my $attr(@{$attrs}) {
            $other->{$attr->{type}} = $attr->{value};
        }
        return {
            cwd     => dirname(__FILE__),
            error   => 0,
            status  => '',
            message => '',
            method  => 'edititem',
            stage   => 'form',
            value   => $params,
            field_map => $self->fieldmap_sorted,
            field_map_json => to_json($self->fieldmap),
            lang_dialect   => $lang,
            lang_all       => $lang_split[0]
        };
    } elsif ( $stage eq 'form' ) {
        # Update submission
        my $submission = $params->{request};
        $submission->updated( DateTime->now );
        $submission->store;

        # We may be receiving a submitted form due to the user having
        # changed request material type, so we just need to go straight
        # back to the form, the type has been changed in the params
        if (defined $other->{change_type}) {
            delete $other->{change_type};
            return {
                cwd     => dirname(__FILE__),
                error   => 0,
                status  => '',
                message => '',
                method  => 'edititem',
                stage   => 'form',
                value   => $params,
                field_map => $self->fieldmap_sorted,
                field_map_json => to_json($self->fieldmap),
                lang_dialect   => $lang,
                lang_all       => $lang_split[0]
            };
        }

        # ...Populate Illrequestattributes
        # generate $request_details
        # We do this with a 'dump all and repopulate approach' inside
        # a transaction, easier than catering for create, update & delete
        my $dbh    = C4::Context->dbh;
        my $schema = Koha::Database->new->schema;
        $schema->txn_do(
            sub{
                # Delete all existing attributes for this request
                $dbh->do( q|
                    DELETE FROM illrequestattributes WHERE illrequest_id=?
                |, undef, $submission->id);
                # Insert all current attributes for this request
                my $type = $other->{RapidRequestType};
                my $fields = $self->fieldmap;

                # First insert our RapidILL fields
                foreach my $field(%{$other}) {
                    my $value = $other->{$field};
                    if (
                        grep( /^$type$/, @{$fields->{$field}->{materials}}) &&
                        $other->{$field} &&
                        length $other->{$field} > 0
                    ) {
                        my @bind = ($submission->id, $field, $value, 0);
                        $dbh->do ( q|
                            INSERT IGNORE INTO illrequestattributes
                            (illrequest_id, type, value, readonly) VALUES
                            (?, ?, ?, ?)
                        |, undef, @bind);
                    }
                }

                # Now insert our core equivalents
                foreach my $field(%{$other}) {
                    my $value = $other->{$field};
                    if (
                        grep( /^$type$/, @{$fields->{$field}->{materials}}) &&
                        $other->{$field} &&
                        $fields->{$field}->{ill} &&
                        length $other->{$field} > 0
                    ) {
                        # The value might need mapping to a core equivalent
                        $value = ($fields->{$field}->{value_map}) ?
                            $fields->{$field}->{value_map}->{$value} :
                            $value;
                        my @bind = ($submission->id, $fields->{$field}->{ill}, $value, 0);
                        $dbh->do ( q|
                            INSERT IGNORE INTO illrequestattributes
                            (illrequest_id, type, value, readonly) VALUES
                            (?, ?, ?, ?)
                        |, undef, @bind);
                    }
                }
            }
        );

        # Create response
        return {
            cwd            => dirname(__FILE__),
            rapidill_config => $self->{_config},
            error          => 0,
            status         => '',
            message        => '',
            method         => 'create',
            stage          => 'commit',
            next           => 'illview',
            value          => $params,
            field_map      => $self->fieldmap_sorted,
            field_map_json => to_json($self->fieldmap),
            lang_dialect   => $lang,
            lang_all       => $lang_split[0]
        };
    }
}

=head3 migrate

Migrate a request into or out of this backend

=cut

sub migrate {
    my ( $self, $params ) = @_;
    my $other = $params->{other};

    my $stage = $other->{stage};
    my $step  = $other->{step};

    my $fields = $self->fieldmap;

    # We may be receiving a submitted form due to the user having
    # changed request material type, so we just need to go straight
    # back to the form, the type has been changed in the params
    if (defined $other->{change_type}) {
        delete $other->{change_type};
        return {
            cwd     => dirname(__FILE__),
            error   => 0,
            status  => '',
            message => '',
            method  => 'create',
            stage   => 'form',
            value   => $params,
            field_map => $self->fieldmap_sorted,
            field_map_json => to_json($self->fieldmap)
        };
    }

    # Recieve a new request from another backend and suppliment it with
    # anything we require specifically for this backend.
    if ( !$stage || $stage eq 'immigrate' ) {
        my $original_request =
          Koha::ILL::Requests->find( $other->{illrequest_id} );
        my $new_request = $params->{request};
        $new_request->borrowernumber( $original_request->borrowernumber );
        $new_request->branchcode( $original_request->branchcode );
        $new_request->status('NEW');
        $new_request->backend( $self->name );
        $new_request->placed( DateTime->now );
        $new_request->updated( DateTime->now );
        $new_request->store;

        # Map from Koha's core fields to our metadata fields
        my $original_id = $original_request->illrequest_id;
        my @original_attributes = $original_request->extended_attributes->search(
            { illrequest_id => $original_id }
        )->as_list;
        my @attributes = keys %{$fields};

        # Look for an equivalent Rapid attribute 
        # for every bit of metadata we receive and, if it exists, map it to the
        # new property
        my $new_attributes = {};
        foreach my $old(@original_attributes) {
            my $rapid = $self->find_rapid_property($old->type);
            if ($rapid) {
                # The value may also need mapping
                my $rapid_value = $self->find_rapid_value($rapid, $old->value);                
                my $value = $rapid_value ? $rapid_value : $old->value;
                $new_attributes->{$rapid} = $value;
            }
        }
        $new_attributes->{migrated_from} = $original_request->illrequest_id;
        while ( my ( $type, $value ) = each %{$new_attributes} ) {
            Koha::ILL::Request::Attribute->new(
                {
                    illrequest_id => $new_request->illrequest_id,
                    # Check required for compatibility with installations before bug 33970
                    column_exists( 'illrequestattributes', 'backend' ) ? (backend =>"RapidILL") : (),
                    type          => $type,
                    value         => $value,
                    readonly      => 0
                }
            )->store;
        }

        return {
            error   => 0,
            status  => '',
            message => '',
            method  => 'migrate',
            stage   => 'commit',
            next    => 'emigrate',
            value   => $params,
            field_map => $self->fieldmap_sorted,
            field_map_json => to_json($self->fieldmap)
        };
    
    } elsif ($stage eq 'emigrate') {
        # We need to cancel any outstanding request with Rapid and then
        # update our local submission
        # Get the request we've migrated from
        my $new_request = $params->{request};
        my $from_id = $new_request->extended_attributes->find(
            { type => 'migrated_from' } )->value;
        my $request = Koha::ILL::Requests->find($from_id);

        my $return = {
            error   => 0,
            status  => '',
            message => '',
            method  => 'migrate',
            stage   => 'commit',
            next    => 'illview',
            value   => $params,
            field_map => $self->fieldmap_sorted,
            field_map_json => to_json($self->fieldmap)
        };

        # Cancel a Rapid request if necessary
        my $cancellation = $self->cancel({ request => $request });

        # If there was a problem cancelling with Rapid, we need to pass
        # that on
        if ($cancellation->{error}) {
            $return->{error} = $cancellation->{error};
            $return->{message} = $cancellation->{message};
        }

        return $return;
    }
}

=head3 _validate_metadata

Test if we have sufficient metadata to create a request for
this material type

=cut

sub _validate_metadata {
    my ($self, $metadata) = @_;
    my $fields = $self->fieldmap();

    my $type = $metadata->{RapidRequestType};
    my $groups = $self->_build_validation_groups($type);

    my %group_validity = ();

    foreach my $group(keys %{$groups}) {
        my $group_fields = $groups->{$group};
        $group_validity{$group} = _is_group_valid($metadata, $group_fields);
    }

    return \%group_validity;
}

sub _validation_group_sizes {
    my ($self) = @_;

    my %res = ();

    for my $type ('Article', 'Book', 'BookChapter') {
        my $groups = $self->_build_validation_groups($type);

        $res{$type} = { map { ($_ => scalar(@{$groups->{$_}})) } (keys %$groups)};
    }

    return \%res;
}

=head3 _build_validation_groups

Build a data structure from the fieldmap which will enable us
to more easily validate group population

=cut

sub _build_validation_groups {
    my ($self, $type) = @_;
    my $groups = {};
    my $fields = $self->fieldmap();
    foreach my $field(keys %{$fields}) {
        if ($fields->{$field}->{required}) {
            my $req = $fields->{$field}->{required};
            foreach my $material(keys %{$req}) {
                if ($material eq $type) {
                    if (!exists $groups->{$req->{$material}->{group}}) {
                        $groups->{$req->{$material}->{group}} = [ $field ];
                    } else {
                        push (@{$groups->{$req->{$material}->{group}}}, $field);
                    }
                }
            }
        }

    }
    return $groups;
}

=head3 _is_group_valid

Is a metadata group valid? i.e. For a group of fields has
at least one of them been populated?

=cut

sub _is_group_valid {
    my ($metadata, $fields) = @_;

    my $valid = 0;
    foreach my $field(@{$fields}) {
        if  (length $metadata->{$field}) {
            $valid++;
        }
    }

    return $valid;
}

=head3 create_submission

Create a local submission, for later RapidILL request creation

=cut

sub create_submission {
    my ($self, $params) = @_;

    my $patron = Koha::Patrons->find( $params->{other}->{borrowernumber} );

    my $request = $params->{request};
    $request->borrowernumber($patron->borrowernumber);
    $request->branchcode($params->{other}->{branchcode});
    $request->status('NEW');
    $request->backend($self->name);
    $request->placed(DateTime->now);
    $request->updated(DateTime->now);

    $request->store;

    # Store the request attributes
    $self->create_illrequestattributes($request, $params->{other});
    # Now store the core equivalents
    $self->create_illrequestattributes($request, $params->{other}, 1);

    return $request;
}

=head3

Store metadata for a given request for our Rapid fields

=cut

sub create_illrequestattributes {
    my ($self, $request, $metadata, $core) = @_;

    # Get the canonical list of metadata fields
    my $fields = $self->fieldmap;

    my $type = $metadata->{RapidRequestType};

    # Get any existing illrequestattributes for this request,
    # so we can avoid trying to create duplicates
    my $existing_attrs = $request->extended_attributes->unblessed;
    my $existing_hash = {};
    foreach my $a(@{$existing_attrs}) {
        $existing_hash->{lc $a->{type}} = $a->{value};
    }
    # Iterate our list of fields
    foreach my $field (keys %{$fields}) {
        # If this field is used in the selected material type
        if (
            grep( /^$type$/, @{$fields->{$field}->{materials}}) &&
            # If we're working with core metadata, check if this field
            # has a core equivalent
            (($core && $fields->{$field}->{ill}) || !$core) &&
            $metadata->{$field} &&
            length $metadata->{$field} > 0
        ) {
            my $att_type = $core ? $fields->{$field}->{ill} : $field;
            # We might need to map the attribute value to our core equivalent
            my $att_value = ($core && $fields->{$field}->{value_map}) ?
                $fields->{$field}->{value_map}->{$metadata->{$field}} :
                $metadata->{$field};

            # If it doesn't already exist for this request
            if (!exists $existing_hash->{lc $att_type}) {
                my $data = {
                    illrequest_id => $request->illrequest_id,
                    # Check required for compatibility with installations before bug 33970
                    column_exists( 'illrequestattributes', 'backend' ) ? (backend =>"RapidILL") : (),
                    type          => $att_type,
                    value         => $att_value,
                    readonly      => 0
                };
                Koha::ILL::Request::Attribute->new($data)->store;
            }
        }
    }
}

=head3 prep_submission_metadata

Given a submission's metadata, probably from a form,
but maybe as an Illrequestattributes object,
and a partly constructed hashref, add any metadata that
is appropriate for this material type

=cut

sub prep_submission_metadata {
    my ($self, $metadata, $return) = @_;

    $return = $return //= {};

    my $metadata_hashref = {};

    if (ref $metadata eq "Koha::ILL::Request::Attributes") {
        while (my $attr = $metadata->next) {
            $metadata_hashref->{$attr->type} = $attr->value;
        }
    } else {
        $metadata_hashref = $metadata;
    }

    # Get our canonical field list
    my $fields = $self->fieldmap;

    my $type = $metadata_hashref->{RapidRequestType};

    # Iterate our list of fields
    foreach my $field(keys %{$fields}) {
        # If this field is used in the selected material type and is populated
        if (
            grep( /^$type$/, @{$fields->{$field}->{materials}}) &&
            $metadata_hashref->{$field} &&
            length $metadata_hashref->{$field} > 0
        ) {
            $return->{$field} = $metadata_hashref->{$field};
        }
    }

    return $return;
}

=head3 submit_and_request

Creates a local submission, then uses the returned ID to create
a RapidILL request

=cut

sub submit_and_request {
    my ($self, $params) = @_;

    # First we create a submission
    my $submission = $self->create_submission($params);

    if (C4::Context->preference('ILLModuleUnmediated')) {
    # Now use the submission to try and create a request with Rapid
        return $self->confirm({ request => $submission });
    } else {
        return { success => 1 };
    }
}

=head3 create_request

Take a previously created submission and send it to RapidILL
in order to create a request

=cut

sub create_request {
    my ($self, $submission) = @_;

    # Add the ID of our newly created submission
    my $metadata = {
        XRefRequestId => $submission->illrequest_id
    };

    $metadata = $self->prep_submission_metadata(
        $submission->extended_attributes,
        $metadata
    );

    # We may need to remove fields prior to sending the request
    my $fields = fieldmap();
    foreach my $field(keys %{$fields}) {
        if ($fields->{$field}->{no_submit}) {
            delete $metadata->{$field};
        }
    }

    # Make the request with RapidILL via the koha-plugin-rapidill API
    my $result = $self->{_api}->InsertRequest( $metadata, $submission->borrowernumber );
    my $error = 0;

    # If the call to RapidILL was successful,
    # add the Rapid request ID to our submission's metadata
    if ($result->{IsSuccessful}) {
        my $rapid_id = $result->{RapidRequestId};
        if ($rapid_id && length $rapid_id > 0) {
            Koha::ILL::Request::Attribute->new({
                illrequest_id => $submission->illrequest_id,
                # Check required for compatibility with installations before bug 33970
                column_exists( 'illrequestattributes', 'backend' ) ? (backend =>"RapidILL") : (),
                type          => 'RapidRequestId',
                value         => $rapid_id
                                               })->store;
        }
        # Add the RapidILL ID to the orderid field
        $submission->orderid($rapid_id);
        # Update the submission status
        $submission->status('REQ')->store;

        # Log the outcome
        $self->log_request_outcome({
            outcome => 'RAPIDILL_REQUEST_SUCCEEDED',
            request => $submission
                                   });

        return { success => 1 };
    } else {
        $error = $result->{errormsg} ? $result->{errormsg} : $result->{VerificationNote};
    }

    # The call to RapidILL failed for some reason. Add the message we got back from the API
    # to the submission's Staff Notes
    $submission->append_to_note("RapidILL request failed:\n" . $error);

    # Log the outcome
    $self->log_request_outcome({
        outcome => 'RAPIDILL_REQUEST_FAILED',
        request => $submission,
        message => $error
    });

    # Return the message
    return {
        success => 0,
        message => $error
    };
}

=head3 confirm

A wrapper around create_request allowing us to
provide the "confirm" method required by
the status graph

=cut

sub confirm {
    my ($self, $params) = @_;

    my $return = $self->create_request($params->{request});

    my $return_value = {
        cwd     => dirname(__FILE__),
        error   => 0,
        status  => "",
        message => "",
        method  => "create",
        stage   => "commit",
        next    => "illview",
        value   => {},
        %{$return}
    };

    return $return_value;
}

=head3 log_request_outcome

Log the outcome of a request to the RapidILL API

=cut

sub log_request_outcome {
    my ($self, $params) = @_;

    if ( $self->{_logger} ) {
        # TODO: This is a transitionary measure, we have removed set_data
        # in Bug 20750, so calls to it won't work. But since 20750 is
        # only in 19.05+, they only won't work in earlier
        # versions. So we're temporarily going to allow for both cases
        my $payload = {
            modulename   => 'ILL',
            actionname   => $params->{outcome},
            objectnumber => $params->{request}->id,
            infos        => to_json({
                log_origin => $self->name,
                response  => $params->{message}
            })
        };
        if ($self->{_logger}->can('set_data')) {
            $self->{_logger}->set_data($payload);
        } else {
            $self->{_logger}->log_something($payload);
        }
    }
}

=head3 get_log_template_path

    my $path = $BLDSS->get_log_template_path($action);

Given an action, return the path to the template for displaying
that action log

=cut

sub get_log_template_path {
    my ( $self, $action ) = @_;
    return $self->{templates}->{$action};
}

=head3 metadata

Return a hashref containing canonical values from the key/value
illrequestattributes store

=cut

sub metadata {
    my ( $self, $request ) = @_;

    my $attrs = $request->extended_attributes;
    my $fields = $self->fieldmap;

    my $typeAttr = $attrs->find({ type => "RapidRequestType" });
    my $type = defined $typeAttr ? $typeAttr->value : 'Article';

    my $metadata = {};

    while (my $attr = $attrs->next) {
        if ($fields->{$attr->type} && $fields->{$attr->type}->{include_in_metadata}) {
            $metadata->{$attr->type} = $attr->value;
        }
    }

    # OPAC list view uses completely different property names for author
    # and title. Cater for that.
    if ($type eq "Article" || $type eq "BookChapter") {
        $metadata->{Title} = $metadata->{ArticleTitle} if $metadata->{ArticleTitle};
        $metadata->{Author} = $metadata->{ArticleAuthor} if $metadata->{ArticleAuthor};
    } elsif ($type eq "Book") {
        $metadata->{Title} = $metadata->{JournalTitle} if $metadata->{JournalTitle};
        $metadata->{Author} = $metadata->{ArticleAuthor} if $metadata->{ArticleAuthor};
    }

    return $metadata;
}

sub metadata0 {
    my ( $self, $params ) = @_;

    my $fields = $self->fieldmap;

    my $type = $params->{RapidRequestType};

    my $metadata = {};

    my %p = %$params;

    while (my ($k, $v) = each %p) {
        if ($fields->{$k} && $fields->{$k}->{include_in_metadata}) {
            $metadata->{$k} = $v;
        }
    }

    return $metadata;
}


=head3 attach_processors

Receive a Koha::Illrequest::SupplierUpdate and attach
any processors we have for it

=cut

sub attach_processors {
    my ( $self, $update ) = @_;

    foreach my $processor(@{$self->{processors}}) {
        if (
            $processor->{target_source_type} eq $update->{source_type} &&
            $processor->{target_source_name} eq $update->{source_name}
        ) {
            $update->attach_processor($processor);
        }
    }
}

=head3 get_supplier_update

Called as a backend capability, receives a local request object
and gets the latest update from RapidILL using their
RetrieveRequestInfo request
Return Koha::Illrequest::SupplierUpdate representing the update

=cut

sub get_supplier_update {
    my ( $self, $params ) = @_;

    my $request = $params->{request};
    my $delay = $params->{delay};

    # Find the submission's Rapid ID
    my $rapid_request_id = $request->extended_attributes->find({
        illrequest_id => $request->illrequest_id,
        type          => "RapidRequestId"
    });

    if (!$rapid_request_id) {
        # No Rapid request, we can't do anything
        print "Request " . $request->illrequest_id . " does not contain a RapidRequestId\n";
        return;
    }

    if ($delay) {
        sleep($delay);
    }

    my $result = $self->{_api}->RetrieveRequestInfo(
        $rapid_request_id->value
    );

    if ($result->{IsSuccessful}) {
        return Koha::ILL::Request::SupplierUpdate->new(
            'backend',
            $self->name,
            $result,
            $request
        );
    }
}

=head3 capabilities

    $capability = $backend->capabilities($name);

Return the sub implementing a capability selected by NAME, or 0 if that
capability is not implemented.

=cut

sub capabilities {
    my ( $self, $name ) = @_;
    my ($query) = @_;
    my $capabilities = {
        # View and manage a request
        illview => sub { illview(@_); },
        # Migrate
        migrate => sub { $self->migrate(@_); },

        edititem => sub { edititem(@_); },

        # Return whether we can create the request
        # i.e. the create form has been submitted
        can_create_request => sub { _can_create_request(@_) },

        # Return whether we are ready to display availability
        should_display_availability => sub { _can_create_request(@_) },
        get_supplier_update => sub { $self->get_supplier_update(@_) }
    };
    return $capabilities->{$name};
}

=head3 _can_create_request

Given the parameters we've been passed, should we create the request

=cut

sub _can_create_request {
     my ($params) = @_;
     return ( defined $params->{'stage'} ) ? 1 : 0;
}


=head3 status_graph

This backend provides no additional actions on top of the core_status_graph

=cut

sub status_graph {
    return {
        EDITITEM => {
            prev_actions   => [ 'NEW' ],
            id             => 'EDITITEM',
            name           => 'Edited item metadata',
            ui_method_name => 'Edit item metadata',
            method         => 'edititem',
            next_actions   => [],
            ui_method_icon => 'fa-edit',
        },
        # Override REQ so we can rename the button
        # Talk about a sledgehammer to crack a nut
        REQ => {
            prev_actions   => [ 'NEW', 'REQREV', 'QUEUED', 'CANCREQ' ],
            id             => 'REQ',
            name           => 'Requested',
            ui_method_name => 'Request from RapidILL',
            method         => 'confirm',
            next_actions   => [ 'REQREV', 'COMP', 'CHK' ],
            ui_method_icon => 'fa-check',
        },
        MIG => {
            prev_actions =>
              [ 'NEW', 'REQ', 'GENREQ', 'REQREV', 'QUEUED', 'CANCREQ', ],
            id             => 'MIG',
            name           => 'Switched provider',
            ui_method_name => 'Switch provider',
            method         => 'migrate',
            next_actions   => [],
            ui_method_icon => 'fa-search',
        },        
    };
}

sub name {
    return "RapidILL";
}

=head3 _fail

=cut

sub _fail {
    my @values = @_;
    foreach my $val (@values) {
        return 1 if ( !$val or $val eq '' );
    }
    return 0;
}

=head3 find_rapid_property

Given a core property name, find the equivalent Rapid
name. Or undef if there is not one

=cut

sub find_rapid_property {
    my ($self, $core) = @_;
    my $fields = $self->fieldmap;
    foreach my $field(keys %{$fields}) {
        if ($fields->{$field}->{ill} && $fields->{$field}->{ill} eq $core) {
            return $field;
        }
    }
}

=head3 find_rapid_value

Given a Rapid property name and core value, find the equivalent Rapid
value. Or undef if there is not one

=cut

sub find_rapid_value {
    my ($self, $rapid_prop, $core_val) = @_;
    my $fields = $self->fieldmap;
    if ($fields->{$rapid_prop}->{value_map}) {
        my $map = $fields->{$rapid_prop}->{value_map};
        while (my($key, $value) = each%{$map}) {
            if ($map->{$key} eq $core_val) {
                return $key;
            }
        }
    }
}

=head3 _openurl_to_ill

Take a hashref of OpenURL parameters and return
those same parameters but transformed to the ILL
schema

=cut

sub _openurl_to_ill {
    my ($params) = @_;

    my $transform_metadata = {
        sid     => 'Sid',
        genre   => 'RapidRequestType',
        content => 'RapidRequestType',
        format  => 'RapidRequestType',
        atitle  => 'ArticleTitle',
        aulast  => 'ArticleAuthor',
        author  => 'ArticleAuthor',
        date    => 'PatronJournalYear',
        issue   => 'JournalIssue',
        volume  => 'JournalVol',
        isbn    => 'SuggestedIsbns',
        issn    => 'SuggestedIssns',
        rft_id  => '',
        year    => 'PatronJournalYear',
        title   => 'PatronJournalTitle',
        author  => 'ArticleAuthor',
        aulast  => 'ArticleAuthor',
        pages   => 'ArticlePages',
        ctitle  => 'ArticleTitle',
        clast   => 'ArticleAuthor',
        doi     => 'DOI'
    };

    my $transform_value = {
        RapidRequestType => {
            fulltext   => 'Article',
            selectedft => 'Article',
            print      => 'Book',
            ebook      => 'Book',
            journal    => 'Article',
            dissertation => 'Article',
            bookitem   => 'BookChapter'
        }
    };

    my $return = {};
    # First make sure our keys are correct
    foreach my $meta_key(keys %{$params->{other}}) {
        # If we are transforming this property...
        if (exists $transform_metadata->{$meta_key}) {
            # ...do it if we have valid mapping
            if (length $transform_metadata->{$meta_key} > 0) {
                $return->{$transform_metadata->{$meta_key}} = $params->{other}->{$meta_key};
            }
        } else {
            # Otherwise, pass it through untransformed
            $return->{$meta_key} = $params->{other}->{$meta_key};
        }
    }
    # Now check our values are correct
    foreach my $val_key(keys %{$return}) {
        my $value = $return->{$val_key};
        if (exists $transform_value->{$val_key} && exists $transform_value->{$val_key}->{$value}) {
            $return->{$val_key} = $transform_value->{$val_key}->{$value};
        }
    }
    $params->{other} = $return;
    return $params;
}

=head3 fieldmap_sorted

Return the fieldmap sorted by "order"
Note: The key of the field is added as a "key"
property of the returned hash

=cut

sub fieldmap_sorted {
    my ($self) = @_;

    my $fields = $self->fieldmap;

    my @out = ();

    foreach my $key (sort {
        $fields->{$a}->{position} <=> $fields->{$b}->{position}
    } keys %{$fields}) {
        my $el = $fields->{$key};
        $el->{key} = $key;
        push @out, $el;
    }

    return \@out;
}

=head3 fieldmap

All fields expected by the API

Key = API metadata element name
  hide = Make the field hidden in the form
  no_submit = Do not pass to RapidILL API
  exclude = Do not include on the entry form
  type = Does an element contain a string value or an array of string values?
  label = Display label
  ill   = The core ILL equivalent field
  help = Display help text
  value_map = Do the Rapid values need mapping to core values
  materials = Material types that expect this element (they may not *require* it)
 required = Hashref of material specific requirements
  Key = Material type that enforces this requirement
    group = Unique name for this grouo

Note regarding requirements: For any fields that are a member of a "group",
an "OR" requirement exists between members of that group
i.e. "You must complete field X OR field Y OR field Z"

=cut

sub fieldmap {
    return {
        RapidRequestType => {
            exclude   => 1,
            type      => "string",
            label     => "Material type",
            label_msg => "material_type",
            ill       => "type",
            position  => 99,
            value_map => {
                Book        => 'book',
                Article     => 'article',
                BookChapter => 'chapter'
            },
            include_in_metadata => 1,
            materials => [ "Article", "Book", "BookChapter" ],
        },
        SuggestedIssns => {
            type      => "array",
            label     => "ISSN",
            label_msg => "issn",
            ill       => "issn",
            position  => 12,
            help      => "Multiple ISSNs must be separated by a space",
            help_msg  => "issn_help",
            materials => [ "Article" ],
            include_in_metadata => 1,
            required  => {
                "Article" => {
                    group   => "ARTICLE_IDENTIFIER",
                    valid_msg => "ok",
                    invalid_msg => "an_article_identifier_required"
                }
            }
        },
        Sid => {
            hide      => 1,
            no_submit => 1,
            exclude   => 1,
            type      => "string",
            label     => "Source identifier",
            position  => 14,
            materials => [ "Article", "Book", "BookChapter" ],
        },
        SuggestedIsbns => {
            type      => "array",
            label     => "ISBN",
            label_msg => "isbn",
            ill       => "isbn",
            position  => 11,
            help      => "Multiple ISBNs must be separated by a space",
            help_msg  => "isbn_help",
            materials => [ "Book", "BookChapter" ],
            include_in_metadata => 1,
            required  => {
                "Book" => {
                    group   => "BOOK_IDENTIFIER",
                    valid_msg => "ok",
                    invalid_msg => "a_book_identifier_required"
                },
                "BookChapter" => {
                    group   => "BOOK_IDENTIFIER",
                    valid_msg => "ok",
                    invalid_msg => "a_book_identifier_required"
                }
            }
        },
        DOI => {
            type      => "string",
            label_msg => "doi_label",
            position  => 0,
            include_in_metadata => 0,
            materials => [ "Article", "BookChapter" ]
        },
        ArticleTitle => {
            type      => "string",
            label_variants  => {
                Article     => "Article title",
                BookChapter => "Book chapter title / number"
            },
            label_msg_variants => {
                Article => "article_title",
                BookChapter => "book_chapter_title"
            },
            ill       => "article_title",
            position  => 2,
            materials => [ "Article", "BookChapter" ],
            include_in_metadata => 1,
            required  => {
                "Article" => {
                    group   => "ARTICLE_ARTICLE_TITLE_PAGES",
                    invalid_msg => "invalid_required_article_article_title_pages"
                },
                "BookChapter" => {
                    group   => "CHAPTER_ARTICLE_TITLE_PAGES",
                    invalid_msg => "invalid_required_chapter_article_title_pages"
                }
            }
        },
        ArticleAuthor => {
            type      => "string",
            label_variants  => {
                Article     => "Article author",
                Book        => "Book author",
                BookChapter => "Book author"
            },
            label_msg_variants => {
                Article     => "article_author",
                Book        => "book_author",
                BookChapter => "book_chapter_author"
            },
            ill       => "article_author",
            position  => 3,
            include_in_metadata => 1,
            materials => [ "Article", "Book", "BookChapter" ]
        },
        ArticlePages => {
            type      => "string",
            label_variants => {
                Article     => "Pages in journal",
                BookChapter => "Pages in book extract"
            },
            label_msg_variants => {
                Article     => "pages_in_journal",
                BookChapter => "pages_in_book_extract"
            },
            ill       => "pages",
            position  => 10,
            materials => [ "Article", "BookChapter" ],
            include_in_metadata => 1,
            required  => {
                "Article" => {
                    group   => "ARTICLE_ARTICLE_TITLE_PAGES",
                    invalid_msg => "invalid_required_article_article_title_pages"
                },
                "BookChapter" => {
                    group   => "CHAPTER_ARTICLE_TITLE_PAGES",
                    invalid_msg => "invalid_required_chapter_article_title_pages"
                }
            }
        },
        PatronJournalTitle => {
            type      => "string",
            label_variants => {
                Article     => "Journal title",
                Book        => "Book title",
                BookChapter => "Book chapter title / number"
            },
            label_msg_variants => {
                Article     => "journal_title",
                Book        => "book_title",
                BookChapter => "book_title"
            },
            ill       => "title",
            position  => 1,
            include_in_metadata => 1,
            materials => [ "Article", "Book", "BookChapter" ],
            required  => {
                "Article" => {
                    group   => "ARTICLE_JOURNAL_TITLE_PAGES",
                    invalid_msg => "invalid_required_article_journal_title_pages"
                },
                "BookChapter" => {
                    group   => "CHAPTER_JOURNL_TITLE_PAGES",
                    invalid_msg => "invalid_required_chapter_journal_title_pages"
                }
            }
        },
        PatronJournalYear => {
            type      => "string",
            label     => "Four digit year of publication",
            label_msg => "year_of_publication",
            ill       => "year",
            position  => 9,
            materials => [ "Article", "Book", "BookChapter" ],
            include_in_metadata => 1,
            required  => {
                "Article" => {
                    group   => "ARTICLE_YEAR_VOL",
                    invalid_msg => "invalid_required_year_vol"
                },
                "BookChapter" => {
                    group   => "ARTICLE_YEAR_VOL",
                    invalid_msg => "invalid_required_year_vol"
                }
            }
        },
        JournalVol => {
            type      => "string",
            label     => "Volume number",
            label_msg => "volume_number",
            ill       => "volume",
            position  => 5,
            materials => [ "Article", "Book", "BookChapter" ],
            include_in_metadata => 1,
            required  => {
                "Article" => {
                    group   => "ARTICLE_YEAR_VOL",
                    invalid_msg => "invalid_required_year_vol"
                }
            }
        },
        JournalIssue => {
            type      => "string",
            label     => "Journal issue number",
            label_msg => "journal_issue_number",
            ill       => "issue",
            position  => 6,
            include_in_metadata => 1,
            materials => [ "Article" ]
        },
        JournalMonth => {
            type      => "string",
            ill       => "item_date",
            position  => 8,
            label     => "Journal month",
            label_msg => "journal_month",
            include_in_metadata => 1,
            materials => [ "Article" ]
        },
        Edition => {
            type      => "string",
            label     => "Book edition",
            label_msg => "book_edition",
            ill       => "part_edition",
            position  => 4,
            include_in_metadata => 1,
            materials => [ "Book", "BookChapter" ]
        },
        Publisher => {
            type      => "string",
            label     => "Book publisher",
            label_msg => "book_publisher",
            ill       => "publisher",
            position  => 7,
            include_in_metadata => 1,
            materials => [ "Book", "BookChapter" ]
        },
        RapidRequestId => {
            exclude   => 1,
            type      => "string",
            ill       => "associated_id",
            label     => "RapidILL identifier",
            label_msg => "rapidill_identifier",
            position  => 99,
            include_in_metadata => 1,
            materials => [ "Article", "Book", "BookChapter" ]
        }
    };
}

=head3 _check_requestability

=cut

sub _check_requestability {
    my $self = shift;
    my $params = shift;

    my $metadata0 = $self->metadata0($params);

    my $metadata = { %$metadata0 };
    # First, is this item available locally
    $metadata->{IsHoldingsCheckOnly} = 1;
    $metadata->{DoBlockLocalOnly} = 0;

    my $response = $self->{_api}->InsertRequest( $metadata );
    if ($self->_is_debug) {
        $self->_debug("check_requestability 1: " . Dumper($response));
    }
    if ($response->{FoundMatch} && exists $response->{LocalHoldings} && ref $response->{LocalHoldings} eq "HASH" && exists $response->{LocalHoldings}->{LocalHoldingItem} && (ref $response->{LocalHoldings}->{LocalHoldingItem}) eq "ARRAY"
        && @{$response->{LocalHoldings}->{LocalHoldingItem}} > 0) {

        return {
            requestable => 0,
            reason => LOCALLY_AVAILABLE,
            holdings => $response->{LocalHoldings}->{LocalHoldingItem}
        };
    }

    $metadata->{PatronNotes} = 'HOLDING_CHECK_DO_REMOTE_SEARCH';
    $response = $self->{_api}->InsertRequest( $metadata );

    if ($self->_is_debug) {
        $self->_debug("check_requestability 2: " . Dumper($response));
    }

    my $requestable = $response->{FoundMatch} &&
        $response->{NumberOfAvailableHoldings} > 0;

    if ( $requestable ) {
        return { requestable => 1 };
    }

    my $note = $response->{errormsg} ? $response->{errormsg} : join ', ', (split '\n\r?+', $response->{VerificationNote});

    return {
        requestable => 0,
        reason => GIVEN_BY_RAPIDILL,
        note => $note
    };
};

my %vn_translations = (
    sv_SE => {
        'Holdings Check Only ' => 'Endast beståndskontroll ',
        'Request Insert Successful ' => 'Beställningen lyckades ',
        'Unable to find matching book ' => 'Kunde inte hitta bok ',
        'Unable to find matching Journal ' => 'Kunde inte hitta tidskrift ',
        'Update successful' => 'Ändringen lyckades'
    }
    );

sub _translate_verification_note {
    my $lang = shift;
    my $note = shift;

    if (exists $vn_translations{$lang}) {
        if (exists $vn_translations{$lang}->{$note}) {
            return $vn_translations{$lang}->{$note};
        }
    }
    return $note;
}

sub _handle_verification_note {
    my $response = shift;
    my $lang = C4::Languages::getlanguage();

    my @vns = split '\n\r?+', $response->{VerificationNote};

    return join ', ', (map { _translate_verification_note($_) } @vns);
}


=head3 _validate_borrower

=cut

sub _validate_borrower {

    # Perform cardnumber search.  If no results, perform surname search.
    # Return ( 0, undef ), ( 1, $brw ) or ( n, $brws )
    my ( $input, $action ) = @_;

    return ( 0, undef ) if !$input || length $input == 0;

    my $patrons = Koha::Patrons->new;
    my ( $count, $brw );
    my $query = { cardnumber => $input };
    $query = { borrowernumber => $input } if ( $action && $action eq 'search_results' );

    my $brws = $patrons->search($query);
    $count = $brws->count;
    my @criteria = qw/ surname userid firstname end /;
    while ( $count == 0 ) {
        my $criterium = shift @criteria;
        return ( 0, undef ) if ( "end" eq $criterium );
        $brws = $patrons->search( { $criterium => $input } );
        $count = $brws->count;
    }
    if ( $count == 1 ) {
        $brw = $brws->next;
    }
    else {
        $brw = $brws;    # found multiple results
    }
    return ( $count, $brw );
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
