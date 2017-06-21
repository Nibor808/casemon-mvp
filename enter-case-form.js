$(document).ready(function() {

    // jQuery.validator.addMethod("multiemails", function (value, element) {
    //     var email = value.split(/[,]+/); // split element by ,
    //     valid = true;
    //     for (var i in email) {
    //         value = email[i];
    //         valid = valid && jQuery.validator.methods.email.call(this, $.trim(value), element);
    //     }
    //     return valid;
    // }, jQuery.validator.messages.multiemails);

      // $.validator.addMethod('startingChars', function() {
    //     str = $('#caseNum').val();
    //     strCheck = str.substring(0, 2);
    //     if (strCheck === "D" || strCheck === "SD") {
    //         return true
    //     }else {
    //         return false
    //     }
    // });

  $('#caseForm').validate({
    debug: true,
      rules: {
        caseNum: {
          minlength: 7,
          maxlength: 8,
          required: true,
          // startingChars: true
        },
        caseNotes: {
          maxlength: 30
        },
        notifEmail: {
          required: true,
          email: true
        }
    },
    messages: {
      caseNum: {
        required: "Please enter a case number",
        minlength: "Please check your case number to ensure it is correct",
        maxlength: "Please check your case number to ensure it is correct"
      },
      caseNotes: {
        maxlength: "Please limit the length of your notes to 30 characters"
      },
      notifEmail: {
        required: "Please enter a valid email address"
      }
    },

    submitHandler: function(caseForm, event) {

      event.preventDefault();

      var caseNumRaw = $('#caseNum').val();
      if (caseNumRaw.substr(0, 1) === "D" || caseNumRaw.substr(0, 1) === "d") {
        var caseType = "D";
        var caseNum = caseNumRaw.substr(1, 6);
      }else if (caseNumRaw.substr(0, 2) === "SD" || caseNumRaw.substr(0, 2) === "sd") {
        caseType = "SD";
        caseNum = caseNumRaw.substr(2, 6);
      }else {
        caseType = $('input:radio[name=caseType]:checked').val();
      }

      var email = $('#notifEmail').val();
      var emailOpt = $('#notifEmail2').val();
      var phone = $('#notifPhone').val();
      var phoneOpt = $('#notifPhone2').val();
      var notes = $('#caseNotes').val();
      var parties = $('#parties').val()
      var phones = '';

      if ($('#notifEmail2').val() === '') {
        var emails = email
      }else {
        emails = email + ',' + emailOpt
      }

      if (phone.length < 5 && phoneOpt.length < 5) {
        phones = ''
      }else if (phoneOpt.length < 5) {
        phones = phone
      }else if (phone.length < 5 && phoneOpt.length > 5) {
        phones = phoneOpt
      }else {
        phones = phone + ',' + phoneOpt
      }

      var data = {
        'caseType' : caseType,
        'caseNum' : caseNum,
        'notes' : notes,
        'phones' : phones,
        'emails' : emails,
        'parties' : parties
      }

      $.ajax({
        type: 'POST',
        url: '/entercase',
        data: data,
        success: function(res) {
          if (res == true) {
            $('#choiceLabel').html('<p>Congratulations!! You entered your case for tracking! Would you like to enter another or take a look at all your cases?</p>')
            $('#choiceModal').modal('show');

          }else if (res === 'over limit'){
            $('#choiceLabel').html('<p><strong>It appears that you have reached or exceeded the number of cases you are allowed to track. Please either delete one of your cases or upgrade your package.</strong></p>');
            $('#choiceModal').modal('show');

          }else {
            $('#choiceLabel').html('<p><strong>There is already a case with that number associated with you in the database.</strong></p>');
            $('#caseForm')[0].reset();
            $('#submitCase').hide();
            $('#choiceModal').modal('show');
          }
        },
        error: function(err) {
            console.log(err);
        },
        timeOut: 5000
      });

        return false;
    }

  });
});