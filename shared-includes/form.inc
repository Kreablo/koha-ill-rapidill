[% BLOCK locally_available %]
  [% MSG.item_locally_available | html %]:
  <ul>
  [% FOREACH holding IN holdings %]
    <li><a href="[% holding.RapidRedirectUrl | html %]" target="_blank">[% holding.RapidRedirectUrl | html %]</a></li>
  [% END %]
  </ul>
[% END %]
[% BLOCK render_field %]
      [% SET key = field.key %]
      [% SET prefix = "${rapid_request_type}_${key}" %]
      [% SET included_material = 0 %]
      [% SET value = whole.value.other.$key %]
      [% IF !value && whole.value.$key %]
         [% SET value = whole.value.$key %]
      [% END %]
      [% FOREACH material IN field.materials %]
        [% IF material == rapid_request_type %]
          [% SET included_material = 1 %]
        [% END %]
      [% END %]
      [% IF included_material && !field.exclude %]
      [% SET validation_group = field.required && field.required.$rapid_request_type ? field.required && field.required.$rapid_request_type : 0 %]
      <li id="[% prefix %]_field"[% IF validation_group %] class="[% IF validation_group.group %][% IF whole.validation_group_sizes.${rapid_request_type}.${validation_group.group} == 1 %]hard-required[% ELSE %]soft-required[% END %][% END %]"[% END %]>
        <label id="[% prefix %]label" for="[% key %]">[% IF field.label_msg_variants %][% MSG.${field.label_msg_variants.$rapid_request_type} | html %][% ELSE %][% MSG.${field.label_msg} | html %][% END %]</label>
        <input type="text" name="[% key %]" class="form-control [% IF whole.group_validity.exists(validation_group.group) %][% IF  whole.group_validity.${validation_group.group} %]is-valid[% ELSE %]is-invalid has-errors[% END %][% END %]"
               id="[% rapid_request_type %]_[% key %]_input"
               value="[% value | html %]"
               [% IF field.help_msg %]aria-describedby="[% prefix %]helpBlock"[% END %]
               [% IF validation_group.group %]data-validation-group="[% validation_group.group %]"[% END %]
                />
        [% IF validation_group.valid_msg %]
        <div class="valid-feedback">
          [% MSG.${validation_group.valid_msg} | html %]
        </div>
        [% END %]
        [% IF validation_group.invalid_msg %]
        <div class="invalid-feedback">
          [% MSG.${validation_group.invalid_msg} | html %]
        </div>
        [% END %]
        [% IF field.help %]
        <div id="[% prefix %]helpBlock" class="help-block">[% MSG.${field.help_msg} | html %]</div>
        [% END %]
      </li>
      [% END %]
[% END %]
[% BLOCK render_errors %]
  [% IF errors || whole.error %]
  <div class="help-block has-error alert alert-danger" role="alert">
  <ul>
    [% IF whole.error %]
      [% IF whole.status == 'missing_fields' %]
        <li>[% MSG.note_some_mandatory_fields_missing | html %]</li>
      [% ELSIF whole.status == 'missing_branch' %]
        <li>[% MSG.note_branch_is_mandatory | html %]</li>
      [% ELSIF whole.status == 'not_requestable' %]
        <li>[% MSG.item_not_requestable | html %]: [% IF whole.rapidill_reason == 'given-by-rapidill' %][% whole.rapidill_note | html %][% ELSIF whole.rapidill_reason == 'locally-available' %][% PROCESS locally_available holdings=whole.rapidill_holdings %][% END %]</li>
      [% ELSIF whole.status == 'invalid_borrower' %]
        <li>[% MSG.note_invalid_borrower_details | html %]</li>
      [% ELSIF whole.status == 'invalid_metadata' %]
        <li>[% MSG.note_invalid_metadata | html %]</li>
      [% ELSIF whole.status == 'invalid_branch' %]
        <li>[% MSG.note_invalid_branch | html %]</li>
      [% ELSIF whole.status == 'api' %]
        <li>[% MSG.service_error | html %]</li>
      [% ELSIF whole.status == 'missing_query' %]
        <li>[% MSG.note_search_query_missing | html %]</li>
      [% ELSIF whole.message %]
        <li><em>[% whole.message %]</em></li>
      [% ELSE %]
        <li><em>[% MSG.unhandled_error | html %]</em></li>
      [% END %]
    [% END %]
    [% FOREACH error IN errors %]
      <li>[% error | html %]</li>
    [% END %]
  </ul>

  </div>
  <div class="alert alert-info" role="alert">
    <p><i class="fa-icon fa-circle-info fa-solid fa-lg"></i> [% MSG.request_failure_alternative %]</p>
  </div>
  [% END %]
[% END %]
[% BLOCK render_create_form %]
[% PROCESS render_form_variant variant='create' %]
[% END %]
[% BLOCK render_edit_form %]
[% PROCESS render_form_variant variant='edit' %]
[% END %]
[% BLOCK render_form_variant %]
<form method="POST" action="[% here %]" id="[% rapid_request_type %]_[% variant %]_form">
  <fieldset class="form-group">
    <legend>[% MSG.enter_metadata | html %]</legend>
    <input type="hidden" value="HV" name="branchcode" />
    [% IF variant == "create" %]
    <input name="stage" value="validate" type="hidden"/>
    <input name="method" value="create" type="hidden"/>
    [% ELSE %]
    <input name="stage" value="form" type="hidden"/>
    <input name="method" value="edititem" type="hidden"/>
    [% END %]
    <input name="RapidRequestType" value="[% rapid_request_type %]" type="hidden" />
    <input name="backend" value="RapidILL" type="hidden"/>
    [% IF Koha.Version.major >= 24 %][% INCLUDE 'csrf-token.inc' %][% END %]
    <ul class="fields">
      [% FOREACH field IN whole.field_map %]
        [% PROCESS render_field field=field rapid_request_type=rapid_request_type field_errors=field_errors %]
      [% END %]
    </ul>
    <div id="[% rapid_request_type %]_messages">
    [% PROCESS render_errors errors=errors %]
    </div>
  </fieldset>
 [% IF variant != 'edit' && staff %]
  <fieldset class="form-group">
    <legend>[% MSG.patron_options | html %]</legend>
    <ul class="fields">
      <li>
        <label for="cardnumber">[% MSG.cardnumber_username_or_surname | html %]</label>
        <input class="form-control" type="text" required="required" autocomplete="off" name="cardnumber" id="cardnumber" type="text"
           value="[% whole.value.other.cardnumber %]" />
      </li>
    </ul>
  </fieldset>
  [% END %]
  <fieldset class="form-group">
    [% IF variant=="create" %]
    <button type="submit" class="btn btn-primary">[% MSG.make_request | html %]</button>
    <a class="btn btn-default" href="[% requests_back_url %]"><span class="fa fa-arrow-left"></span> [% MSG.back_to_requests | html %]</a>
    [% ELSE %]
    <button type="submit" class="btn btn-primary">[% MSG.update | html %]</button>
    <a class="btn btn-default" href="[% requests_back_url %]"><span class="fa fa-arrow-left"></span> [% MSG.back_to_request | html %]</a>
    [% END %]
  </fieldset>
</form>
[% END %]