/* eslint-disable */
import Filter from "bad-words";

// Some FormData methods like .set or .get are not supported in IE:
// (https://developer.mozilla.org/en-US/docs/Web/API/FormData#Browser_compatibility)
// so we need to make use of a polyfill:
import FormData from "formdata-polyfill";

export default function($ = window.jQuery) {
  document.addEventListener(
    "turbolinks:load",
    () => {
      // TODO: create a way to run page-specific JS so that this hack isn't needed.
      if (!document.getElementById("support-form")) {
        return;
      }

      window.nextTick(() => {
        clearFallbacks($);

        const toUpload = [];
        setupPhotoPreviews($, toUpload);
        setupTextArea();
        setupRequestResponse($);
        setupSubject($);
        setupValidation($);

        handleSubmitClick($, toUpload);
        handleModeChangeSelection($);
        handleSubjectChange($);
      });
    },
    { passive: true }
  );
}

export function handleModeChangeSelection($) {
  const modeOptionsEl = document.getElementById("js-routes-by-mode");
  const modeOptions = JSON.parse(modeOptionsEl.innerHTML);

  const vehicleLabels = {
    bus: "Bus",
    commuter_rail: "Train",
    subway: "Vehicle",
    ferry: "Boat"
  };

  // initially hide the choices for route and vehicle
  $("#route-and-vehicle").hide();

  const modeSelect = document.getElementById("support_mode");
  modeSelect.addEventListener(
    "change",
    ev => {
      // empty contents of the select first:
      $("#support_route").empty();

      const routeSelect = document.getElementById("support_route");

      // Get the text property of the <option> selected
      // and build key in order to access the 'modeOptions' object

      // .selectedOptions is not supported by IE so a workaround is needed:
      const selectedText = ev.target.selectedOptions
        ? ev.target.selectedOptions[0].text
        : ev.target.options[ev.target.selectedIndex].innerText;

      const key = selectedText
        .split(" ")
        .map(el => el.toLowerCase())
        .join("_");

      const opts = modeOptions[`${key}_options`];

      if (!!opts) {
        $("#route-and-vehicle").show();
        // update label:
        $("#vehicleLabel").text(`${vehicleLabels[key]} number`);

        // Create options for the select (prepending an extra one for 'Select'):
        const option = document.createElement("option");
        option.text = "Select";
        option.value = " ";
        routeSelect.appendChild(option);

        opts.forEach(element => {
          const opt = document.createElement("option");
          opt.text = element;
          opt.value = element;
          routeSelect.appendChild(opt);
        });
      } else {
        $("#route-and-vehicle").hide();
      }
    },
    { passive: true }
  );
}

// Set a few things since we know we don't need the no-JS fallbacks
export function clearFallbacks($) {
  const $photoLink = $("#upload-photo-link"),
    $photoInput = $("#photo");
  // Remove tabindex manipulation for screenreaders
  $photoLink.removeAttr("tabindex");
  // Forward clicks from the button to the input
  $photoLink.click(function(event) {
    event.preventDefault();
    $photoInput.click();
  });
}

// Adds the uploaded photo previews
function setupPhotoPreviews($, toUpload) {
  const $container = $(".photo-preview-container");
  $("#photo").change(function() {
    if (this.files.length >= 1) {
      resizeAndHandleUploadedFile($, this.files[0], $container, toUpload);
    }
  });
}

export function resizeAndHandleUploadedFile($, file, $container, toUpload) {
  if (/image\//.test(file.type)) {
    resizeImage(file)
      .then(newFile => {
        newFile.name = file.name;
        handleUploadedPhoto($, newFile, $container, toUpload);
        $("#support-upload-error-container").addClass("hidden-xs-up");
      })
      .catch(err => {
        displayError($, "#upload");
        $("#upload-photo-error").html(
          "Sorry. We had trouble uploading your image. Please try again."
        );
      });
  } else {
    displayError($, "#upload");
    $("#upload-photo-error").html(
      "We couldn't upload your file. Please make sure it's an image and try again."
    );
  }
  $container.focus();
}

// Split out for testing, since the content of a file input can't be
// changed programmatically for security reasons
export function handleUploadedPhoto($, file, $container, toUpload) {
  toUpload.push(file);
  hideOrShowPreviews($container, toUpload);

  let preview = new PhotoPreview($, file)
    .addClickHandler($container, toUpload)
    .div();
  $container.append(preview);
}

export function resizeImage(file) {
  return new Promise((resolve, reject) => {
    const fr = new FileReader();
    fr.onerror = () => {
      fr.abort();
      reject(new DOMException("Error parsing file."));
    };
    fr.onload = function() {
      const img = new Image();
      img.onload = function() {
        const dim = rescale({ width: img.width, height: img.height });
        const canvas = document.createElement("canvas");
        canvas.width = dim.width;
        canvas.height = dim.height;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(img, 0, 0, dim.width, dim.height);
        canvas.toBlob(function(blob) {
          resolve(blob);
        }, "image/jpeg");
      };
      img.src = fr.result;
    };
    fr.readAsDataURL(file);
  });
}

export function rescale(dim) {
  const maxDim = 1000;
  if (dim.width <= maxDim && dim.height <= maxDim) {
    return dim;
  }
  if (dim.width > dim.height) {
    const ratio = dim.height / dim.width;
    dim.width = maxDim;
    dim.height = maxDim * ratio;
  } else {
    const ratio = dim.width / dim.height;
    dim.height = maxDim;
    dim.width = maxDim * ratio;
  }
  return dim;
}

function hideOrShowPreviews($container, toUpload) {
  if (toUpload.length > 0) {
    $container.removeClass("hidden-xs-up");
  } else {
    $container.addClass("hidden-xs-up");
  }
}

function PhotoPreview($, file) {
  const filesize = require("filesize");

  let $div = $(`
    <div class="photo-preview">
      <div class="clear-upload-container">
        <img height="64" class="m-r-1" alt="Uploaded image ${
          file.name
        } preview"></img>
        <div class="clear-photo">
          <i class="fa fa-circle fa-stack-1x" style="color: white" aria-hidden="true"></i>
          <i class="fa fa-times-circle fa-stack-1x" aria-hidden="true"></i>
          <span class="sr-only">Clear Photo Upload</span>
        </div>
      </div>
    </div>
  `);

  let reader = new FileReader();
  reader.onloadend = () => {
    $div.find("img")[0].src = reader.result;
  };
  reader.readAsDataURL(file);

  this.addClickHandler = function($container, toUpload) {
    $div.find(".clear-photo").click(event => {
      event.preventDefault();

      let index = toUpload.indexOf(file);
      toUpload.splice(index, 1);
      $div.remove();

      hideOrShowPreviews($container, toUpload);
    });
    return this;
  };

  this.div = function() {
    return $div;
  };
}

export function setupTextArea() {
  // Track the number of characters in the main <textarea>
  const commentsNode = document.getElementById("comments"),
    formTextNode = findSiblingWithClass(commentsNode, "form-text");
  commentsNode.addEventListener(
    "keyup",
    ev => {
      // .textLength is not supported in IE
      // (https://developer.mozilla.org/en-US/docs/Web/API/HTMLTextAreaElement#Browser_compatibility)
      const commentLength = commentsNode.value.length;
      formTextNode.innerHTML = commentLength + "/3000 characters";
      if (commentLength > 0) {
        formTextNode.className += " support-comment-success";
        formTextNode.parentNode.className += " has-success";
      } else {
        removeClass(formTextNode, "support-comment-success");
        removeClass(formTextNode.parentNode, "has-success");
      }
    },
    { passive: true }
  );
}

export function setupSubject($) {
  const support_service_opts = JSON.parse(
    document.getElementById("js-subjects-by-service").innerHTML
  );
  // show the field once a category is selected
  $("[name='support[service]']").change(function() {
    // remove all <options> except the first
    $("#support_subject option")
      .nextAll()
      .remove();
    const selectedCategory = $("[name='support[service]']:checked").val();
    const selectedOptions = support_service_opts[selectedCategory];
    if (selectedOptions) {
      $("#support_subject").append(
        selectedOptions.map(
          opt => `<option value=${encodeURIComponent(opt)}>${opt}</option>`
        )
      );
    }
  });
}

function findSiblingWithClass(node, className) {
  node = node.nextElementSibling;
  while (node && node.className.indexOf(className) === -1) {
    node = node.nextElementSibling;
  }
  return node;
}
function removeClass(node, className) {
  node.className = node.className.replace(className, "");
}

export function setupRequestResponse($) {
  $("#no_request_response").change(function() {
    $("#contactInfoForm").toggle(!$(this).is(":checked"));
  });
}

const validators = {
  comments: function($) {
    return $("#comments").val().length !== 0;
  },
  subject: function($) {
    return $("#support_subject").val().length !== 0;
  },
  service: function($) {
    return !!$("[name='support[service]']:checked").val();
  },
  first_name: function($) {
    if (responseRequested($)) {
      return $("#first_name").val().length !== 0;
    }
    return true;
  },
  last_name: function($) {
    if (responseRequested($)) {
      return $("#last_name").val().length !== 0;
    }
    return true;
  },
  email: function($) {
    if (responseRequested($)) {
      return (
        $("#email")
          .val()
          .trim()
          .match(/.+\@.+\..+/) !== null
      );
    }
    return true;
  },
  privacy: function($) {
    if (responseRequested($)) {
      return $("#privacy").prop("checked");
    }
    return true;
  },
  recaptcha: function($) {
    return !!$("#g-recaptcha-response").val();
  },
  vehicle: function($) {
    const value = $("#vehicle").val();
    return /^[0-9]*$/.test(value);
  }
};

function responseRequested($) {
  return !$("#no_request_response")[0].checked;
}

function setupValidation($) {
  [
    "#privacy",
    "#support_subject",
    "#comments",
    "#email",
    "#first_name",
    "#last_name",
    "#vehicle"
  ].forEach(selector => {
    const $selector = $(selector);
    $selector.on("keyup blur input change", () => {
      if (validators[selector.slice(1)]($)) {
        displaySuccess($, selector);
      }
    });
  });
}

function displayError($, selector) {
  const rootSelector = selector.slice(1);
  $(`.support-${rootSelector}-error-container`).removeClass("hidden-xs-up");
  $(selector)
    .parent()
    .addClass("has-danger")
    .removeClass("has-success");
}

function displaySuccess($, selector) {
  $(`.support-${selector.slice(1)}-error-container`).addClass("hidden-xs-up");
  $(selector)
    .parent()
    .removeClass("has-danger")
    .addClass("has-success");
}

function validateForm($) {
  const privacy = "#privacy",
    subject = "#support_subject",
    comments = "#comments",
    service = "#service",
    vehicle = "#vehicle",
    email = "#email",
    first_name = "#first_name",
    last_name = "#last_name",
    recaptcha = "#g-recaptcha-response",
    errors = [];
  // Service
  if (!validators.service($)) {
    displayError($, service);
    errors.push(service);
  } else {
    displaySuccess($, service);
  }
  // Subject
  if (!validators.subject($)) {
    displayError($, subject);
    errors.push(subject);
  } else {
    displaySuccess($, subject);
  }
  // Main textarea
  if (!validators.comments($)) {
    displayError($, comments);
    errors.push(comments);
  } else {
    displaySuccess($, comments);
  }
  // Name
  if (!validators.first_name($)) {
    displayError($, first_name);
    errors.push(first_name);
  } else {
    displaySuccess($, first_name);
  }
  if (!validators.last_name($)) {
    displayError($, last_name);
    errors.push(last_name);
  } else {
    displaySuccess($, last_name);
  }
  // Vehicle number
  if (!validators.vehicle($)) {
    displayError($, vehicle);
    errors.push(vehicle);
  } else {
    displaySuccess($, vehicle);
  }
  // Phone and email
  if (!validators.email($)) {
    displayError($, email);
    errors.push(email);
  } else {
    displaySuccess($, email);
  }
  // Privacy checkbox
  if (!validators.privacy($)) {
    displayError($, privacy);
    errors.push(privacy);
  } else {
    displaySuccess($, privacy);
  }
  // reCAPTCHA
  if (!validators.recaptcha($)) {
    displayError($, recaptcha);
    errors.push(recaptcha);
  } else {
    displaySuccess($, recaptcha);
  }
  focusError($, errors);
  return errors.length === 0;
}

function focusError($, errors) {
  if (errors.length > 0) {
    $(`.support-${errors[0].slice(1)}-error-container`).focus();
  }
}

function deactivateSubmitButton($) {
  $("#support-submit").prop("disabled", true);
  $(".waiting").removeAttr("hidden");
  $("#support-submit").trigger("waiting:start");
}

function reactivateSubmitButton($) {
  $("#support-submit").prop("disabled", false);
  $(".waiting").attr("hidden", "hidden");
  $("#support-submit").trigger("waiting:end");
}

export function handleSubmitClick($, toUpload) {
  $("#support-submit").click(function(event) {
    // Use an npm-installed library for testing
    const FormData = window.FormData ? window.FormData : require("form-data"),
      valid = validateForm($);
    event.preventDefault();
    if (!valid) {
      return;
    }
    deactivateSubmitButton($);
    const formData = new FormData();
    const filter = new Filter();
    $("#support-form")
      .serializeArray()
      .forEach(({ name: name, value: value }) => {
        if (name === "support[comments]") {
          value = filter.clean(value);
        }
        formData.append(name, value);
      });

    // overwrite subject value with the decoded content:
    const encodedSubjectValue = formData.get("support[subject]");
    formData.set("support[subject]", decodeURIComponent(encodedSubjectValue));

    toUpload.forEach(photo => {
      formData.append("support[photos][]", photo, photo.name);
    });
    $.ajax({
      url: $("#support-form").attr("action"),
      method: "POST",
      processData: false,
      data: formData,
      contentType: false,
      success: () => {
        $(".support-confirmation--success")
          .removeClass("hidden-xs-up")
          .focus();
        $(".support-confirmation--error").addClass("hidden-xs-up");
        reactivateSubmitButton($);
        $("#support-form").remove();
      },
      error: () => {
        $(".support-confirmation--error")
          .removeClass("hidden-xs-up")
          .focus();
        reactivateSubmitButton($);
      }
    });
  });
}

export function handleSubjectChange($) {
  $("#charlie-card-or-ticket-number").hide();
  const subjectEl = document.getElementById("support_subject");
  subjectEl.addEventListener("change", ev => {
    const optionText = ev.target.options[ev.target.selectedIndex].text;
    if (ev.target.value === encodeURIComponent("CharlieCards & Tickets")) {
      $("#charlie-card-or-ticket-number").show();
    } else {
      $("#charlie-card-or-ticket-number").hide();
    }
  });
}
