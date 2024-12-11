// Add the appropriate label for each input
function addLabels() {
    var selected = $('#type').val();
    Object.keys(fieldmap).forEach(function (key) {
        var label = typeof fieldmap[key].label === 'object' ?
            fieldmap[key].label[selected] :
            fieldmap[key].label;
        $('#' + key + '_label').text(label);
    });

};

// Show or hide fields depending on selected type
function showFields() {
    var selected = $('#type').val();
    Object.keys(fieldmap).forEach(function (key) {
        if (fieldmap[key].materials.indexOf(selected) == -1) {
            $('#rapid_field_' + key).hide();
        } else {
            $('#rapid_field_' + key).show();
        }
    });
};

// Build the groups used for validation
function buildValidationGroups() {
    var groups = {};
    Object.keys(fieldmap).forEach(function (field) {
        if (fieldmap[field].required) {
            var req = fieldmap[field].required;
            Object.keys(req).forEach(function (material) {
                if (material === $('#type').val()) {
                    if (!groups[req[material].group]) {
                        groups[req[material].group] = [field];
                    } else {
                        groups[req[material].group].push(field);
                    }
                }
            });
        }
    });
    return groups;
};

// Does a given group of fields have at least one populated input?
function isGroupValid(fields) {
    var filtered = fields.filter(function (field) {
        if ($('#rapid_field_' + field + ' input').val().length > 0) {
            return field;
        }
    });
    return filtered.length > 0;
};

// Show / hide warning and manage content
function manageWarning(messages) {
    var warning = $('#rapid_warning');
    if (messages.length === 0) {
        warning.css('visibility', 'hidden');
        warning.empty();
    } else {
        var listItems = messages.map(function (message) {
            return "<li>" + message + "</li>";
        });
        var content = '<ul id="rapid_warnings">' + listItems.join('') + "</ul>"
        warning.empty();
        warning.append(content);
        warning.css('visibility', 'visible');
    }
};

function isOpac() {
    var re = new RegExp(/opac/);
    return re.test(window.location.pathname);
}

// Enable / disable submit button based on validation
// but only on intranet
function manageSubmit(messages) {
    if (!isOpac()) {
        $("#rapid_submit").attr('disabled', messages.length > 0);
    }
}

// Add event handlers for fields that need them
function addHandlers() {
    var handleMe = [];
    Object.keys(fieldmap).forEach(function (field) {
        if (fieldmap[field].required && $("#" + field).is(':visible')) {
            handleMe.push("#rapid_field_" + field + " input");
        }
    });
    // Add the fields that cannot be empty
    handleMe = handleMe.concat(notEmpty.map(function (ne) {
        return '#' + ne;
    }));
    if (handleMe.length > 0) {
        var selectors = handleMe.join(',');

        // Remove pre-existing handlers
        if (listenerSelectors.length > 0) {
            $(selectors).off('keyup')
        }

        $(selectors).on('keyup', function () {
            validateFields();
            listenerSelectors = selectors;
        });
    }
};

// Validate fields and display warnings
function validateFields() {
    var type = $('#type').val();
    // Get our validation groups
    var messages = [];
    var groups = buildValidationGroups();
    Object.values(groups).forEach(function (fields) {
        if (!isGroupValid(fields)) {
            var fieldNames = fields.map(function (field) {
                return typeof fieldmap[field].label === 'object' ?
                    fieldmap[field].label[type] :
                    fieldmap[field].label;
            });
            messages.push(
                _("You must complete at least one of the following fields: ") + fieldNames.join(', ')
            );
        }
    });
    // Handle fields that aren't in groups
    notEmpty.forEach(function (key) {
        var inpVal = $('#' + key).val();
        if (!inpVal || inpVal.length === 0) {
            var name = $('body').find('label[for="' + key + '"]').text().replace(/:/, '');
            messages.push(
                '"' + name + _('" cannot be empty')
            );
        }
    });
    manageWarning(messages);
    manageSubmit(messages);
};

$('#rapid_submit').click(function() {
  $('#create_form').submit();
  $(this).prop('disabled', true);
});
