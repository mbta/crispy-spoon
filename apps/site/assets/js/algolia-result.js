import hogan from "hogan.js";
import * as Icons from "./icons";

/* eslint-disable no-underscore-dangle */

export const SELECTORS = {
  result: "js-search-result"
};

export const TEMPLATES = {
  poweredByGoogleLogo: hogan.compile(
    `<div class="c-search-result__hit c-search-result__google">{{{logo}}}</div>`
  ),
  fontAwesomeIcon: hogan.compile(
    `<span aria-hidden="true" class="c-search-result__content-icon fa {{icon}}"></span>`
  ),
  formattedDate: hogan.compile(
    `<span class="c-search-result__event-date">{{date}}</span>`
  ),
  locations: hogan.compile(`
    <a id="hit-{{id}}" class="c-search-result__link u-no-underline" url={{hitUrl}}>
      <span>{{{hitIcon}}}</span>
      <span class="c-search-result__hit-name">{{{hitTitle}}}</span>
    </a>
  `),
  usemylocation: hogan.compile(`
    <a id="search-bar__my-location" class="c-search-bar__my-location">
      <i aria-hidden="true" class="fa fa-location-arrow "></i>
      Use my location
      <i aria-hidden="true" id="search-result__loading-indicator" class="fa fa-cog fa-spin c-search-result__loading-indicator"></i>
    </a>
  `),
  projects: hogan.compile(`
    {{#hasDate}}
    <div class="c-search-result__hit--vertical">
    {{/hasDate}}
    {{#id}}
    <a id="hit-{{id}}" class="${
      SELECTORS.result
    } c-search-result__link" href="{{hitUrl}}">
    {{/id}}
    {{^id}}
    <a class="${
      SELECTORS.result
    } c-search-result__link u-no-underline" href="{{hitUrl}}" data-queryid="{{analyticsData.queryID}}" data-hit-position="{{analyticsData.position}}" data-objectid="{{analyticsData.objectID}}">
    {{/id}}
      <span class="c-search-result__hit-name">{{{hitTitle}}}</span>
    </a>
    <span>{{{hitIcon}}}</span>
    {{#hasDate}}
    </div>
    {{/hasDate}}
  `),
  default: hogan.compile(`
    {{#hasDate}}
    <div class="c-search-result__hit--vertical">
    {{/hasDate}}
    {{#id}}
    <a id="hit-{{id}}" class="${
      SELECTORS.result
    } c-search-result__link" href="{{hitUrl}}">
    {{/id}}
    {{^id}}
    <a class="${
      SELECTORS.result
    } c-search-result__link u-no-underline" href="{{hitUrl}}" data-queryid="{{analyticsData.queryID}}" data-hit-position="{{analyticsData.position}}" data-objectid="{{analyticsData.objectID}}">
    {{/id}}
      <span>{{{hitIcon}}}</span>
      <span class="c-search-result__hit-name">{{{hitTitle}}}</span>
    </a>
    <span class="c-search-result__feature-icons">
      {{#hitFeatureIcons}}
        {{{.}}}
      {{/hitFeatureIcons}}
    </span>
    {{#hasDate}}
    </div>
    {{/hasDate}}
  `)
};

function iconsFromGTFSAncestries(ancestries) {
  return ancestries
    .map(anc => anc.toLowerCase())
    .filter(anc => anc !== "subway")
    .map(anc => Icons.getFeatureIcon(anc));
}

function iconsFromGTFSAncestry(ancestry) {
  if (Array.isArray(ancestry)) {
    return iconsFromGTFSAncestries(ancestry);
  }
  return iconsFromGTFSAncestries([ancestry]);
}

function _subwayRouteIcon(routeId) {
  if (routeId.includes("Green-")) {
    return routeId.toLowerCase().replace("-", "_line_");
  }

  const mapper = {
    Green: "green_line",
    Red: "red_line",
    Orange: "orange_line",
    Blue: "blue_line",
    Mattapan: "mattapan_line"
  };

  return mapper[routeId];
}

function iconFromGTFSId(id, route_name) {
  const toSubway = _subwayRouteIcon(id);
  if (toSubway) {
    return Icons.getFeatureIcon(toSubway);
  }
  if (route_name.startsWith('SL')) {
    return Icons.getFeatureIcon("silver_line");
  }
  if (id in ["commuter_rail", "bus", "ferry"]) {
    return Icons.getFeatureIcon(id);
  }
  if (id.includes("CR-")) {
    return Icons.getFeatureIcon("commuter_rail");
  }
  return Icons.getFeatureIcon(id);
}

function iconsFromGTFSIds(id, route_name) {
  if (Array.isArray(id)) {
    return id.map(icon => iconFromGTFSId(icon,route_name));
  }
  return [iconFromGTFSId(id,route_name)];
}

export function iconFromGTFS(id, ancestry, route_name) {
  if (!id) {
    return TEMPLATES.fontAwesomeIcon.render({ icon: "fa-info" });
  }
  let icons = iconsFromGTFSIds(id, route_name);
  if (ancestry) {
    icons = [...new Set([...icons, ...iconsFromGTFSAncestry(ancestry)])];
  }
  return icons;
}

function _fileIcon(hit) {
  switch (hit._file_type) {
    case "application/pdf":
      return "fa-file-pdf-o";

    case "application/vnd.openxmlformats-officedocument.presentationml.presentation":
    case "application/vnd.ms-powerpoint":
      return "fa-file-powerpoint-o";

    case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
    case "application/vnd.ms-excel":
      return "fa-file-excel-o";

    case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
    case "application/msword":
      return "fa-file-word-o";

    default:
      return "fa-file-o";
  }
}

function _contentIcon(hit) {
  let icon;

  if (hit.search_api_datasource === "entity:file") {
    icon = _fileIcon(hit);
  } else {
    const iconMapper = {
      search_result: "fa-info",
      news_entry: "fa-newspaper-o",
      event: "fa-calendar",
      project: "fa-wrench",
      project_update: "fa-wrench",
      page: "fa-info",
      landing_page: "fa-info",
      person: "fa-user",
      locations: "fa-map-marker"
    };
    icon = iconMapper[hit._content_type] || "fa-info";
  }

  return TEMPLATES.fontAwesomeIcon.render({ icon });
}

function _getStopOrStationIcon(hit) {
  if (hit.stop["station?"]) {
    return Icons.getFeatureIcon("station");
  }
  return Icons.getFeatureIcon("stop");
}

function _iconFromRoute(route) {
  switch (route.type) {
    case 2:
      return "commuter_rail";

    case 3:
      return "bus";

    case 4:
      return "ferry";

    case 5:
      return "silver_line";

    default:
      return _subwayRouteIcon(route.id);
  }
}

function getPopularIcon(icon) {
  switch (icon) {
    case "airplane":
      return TEMPLATES.fontAwesomeIcon.render({ icon: "fa-plane" });
    default:
      return Icons.getFeatureIcon(icon);
  }
}

export function getIcon(hit, type) {
  switch (type) {
    case "locations":
      return _contentIcon({ ...hit, _content_type: "locations" });
    case "stops":
      return _getStopOrStationIcon(hit);

    case "routes":
      return Icons.getFeatureIcon(_iconFromRoute(hit.route));

    case "popular":
      return getPopularIcon(hit.icon);

    case "projects":
      return getTransitIcons(hit);

    case "drupal":
    case "pages":
    case "documents":
    case "events":
    case "news":
      return _contentIcon(hit);

    case "usemylocation":
      return "";

    default:
      return "";
  }
}

function getTransitIcons(hit) {
  if (
    hit.related_transit_gtfs_id === null &&
    hit.related_transit_gtfs_ancestry == null
  ) {
    return "";
  }
  const icons = iconFromGTFS(
    hit.related_transit_gtfs_id,
    hit.related_transit_gtfs_ancestry,
    hit._highlightResult.route.name.value
  );
  if (Array.isArray(icons)) {
    return icons.join(" ");
  }
  return icons;
}

function _contentUrl(hit) {
  if (hit.search_api_datasource === "entity:file") {
    return `/sites/default/files/${hit._file_uri.replace(/public:\/\//, "")}`;
  }
  if (hit._content_type === "search_result") {
    return hit._search_result_url.replace(/internal:/, "");
  }
  return hit._content_url;
}

export function getUrl(hit, index) {
  switch (index) {
    case "stops":
      return `/stops/${hit.stop.id}`;

    case "routes":
      return `/schedules/${hit.route.id}`;

    case "popular":
      return hit.url;

    case "drupal":
    case "projects":
    case "pages":
    case "documents":
    case "events":
    case "news":
      return _contentUrl(hit);

    case "locations":
      return "";
    case "usemylocation":
      return "#";

    default:
      return "#";
  }
}

function getRouteTitle(hit) {
  const name = hit._highlightResult.route.name.value;
  switch (hit.route.type) {
    case 3:
      return `${name} <span class="c-search-result__long-name">${
        hit._highlightResult.route.long_name.value
      }</span>`;
    default:
      return name;
  }
}

function _contentTitle(hit) {
  if (hit._content_type === "search_result") {
    return hit._highlightResult.search_result_title.value;
  }
  if (hit.search_api_datasource === "entity:file") {
    return hit._highlightResult.file_name_raw.value;
  }
  return hit._highlightResult.content_title.value;
}

export function getTitle(hit, type) {
  let orig;
  switch (type) {
    case "locations":
      orig = hit.description.split("");
      hit.matched_substrings.forEach(match => {
        orig[match.offset] = `<em>${orig[match.offset]}`;
        if (match.offset + match.length < orig.length) {
          orig[match.offset + match.length] = `</em>${
            orig[match.offset + match.length]
          }`;
        }
      });
      return orig.join("");
    case "stops":
      return hit._highlightResult.stop.name.value;

    case "routes":
      return getRouteTitle(hit);

    case "popular":
      return hit.name;

    case "drupal":
    case "projects":
    case "pages":
    case "documents":
    case "events":
    case "news":
      return _contentTitle(hit);

    case "usemylocation":
      return "";

    default:
      return "";
  }
}

function _stopsWithAlerts() {
  const stopsWithAlertsDiv = document.getElementById("stops-with-alerts");
  if (!stopsWithAlertsDiv) return "";
  const {
    dataset: { stopsWithAlerts }
  } = stopsWithAlertsDiv;
  return stopsWithAlerts;
}

function _routesWithAlerts() {
  const routesWithAlertsDiv = document.getElementById("routes-with-alerts");
  if (!routesWithAlertsDiv) return "";
  const {
    dataset: { routesWithAlerts }
  } = routesWithAlertsDiv;
  return routesWithAlerts;
}

function _getAlertIcon(hit, type) {
  let hasAlert = false;
  switch (type) {
    case "stops":
      hasAlert = _stopsWithAlerts().includes(hit.stop.id);
      break;

    case "routes":
      hasAlert = _routesWithAlerts().includes(hit.route.id);
      break;

    default:
      hasAlert = false;
  }

  return hasAlert ? ["alert"] : [];
}

function _standardizeFeatureName(feature) {
  switch (feature) {
    case "Red":
    case "Blue":
    case "Orange":
    case "Green":
    case "Green-B":
    case "Green-C":
    case "Green-D":
    case "Green-E":
    case "Mattapan":
      return _subwayRouteIcon(feature);

    default:
      return feature;
  }
}

function _featuresToIcons(features) {
  return features.map(feature =>
    Icons.getFeatureIcon(_standardizeFeatureName(feature))
  );
}

function _sortFeatures(features) {
  const featuresWithoutBranches = features.filter(
    feature => !feature.includes("Green-")
  );
  const branches = features.filter(feature => feature.includes("Green-"));
  if (branches.length > 0) {
    const greenLinePosition = featuresWithoutBranches.findIndex(
      feature => feature === "green_line"
    );

    featuresWithoutBranches.splice(greenLinePosition + 1, 0, ...branches);
    return featuresWithoutBranches;
  }
  return features;
}

function _getCommuterRailZone(hit) {
  if (hit.zone) {
    return [`<span class="c-icon__cr-zone">Zone ${hit.zone}</span>`];
  }
  return [];
}

function _stopIcons(hit, type) {
  const filteredFeatures = hit.features.filter(
    feature => feature !== "access" && feature !== "parking_lot"
  );

  const alertFeature = _getAlertIcon(hit, type);
  const allFeatures = alertFeature.concat(filteredFeatures);
  const allFeaturesSorted = _sortFeatures(allFeatures);
  const allIcons = _featuresToIcons(allFeaturesSorted);

  const zoneIcon = _getCommuterRailZone(hit);

  return allIcons.concat(zoneIcon);
}

function _formatDate(date) {
  const formattedDate = date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric"
  });
  return TEMPLATES.formattedDate.render({ date: formattedDate });
}

function pagesdocumentsDate(hit) {
  if (hit._file_created !== undefined) {
    const date = new Date(hit._file_created * 1000);
    return [_formatDate(date)];
  }
  return [];
}

function projectsDate(hit) {
  if (hit._content_posted_on) {
    const date = new Date(hit._content_posted_on * 1000);
    return [_formatDate(date)];
  }
  return [];
}

function _contentDate(hit) {
  const dateString = hit._content_url.split("/")[2];
  try {
    const dateStringWithTime = `${dateString}T01:00:00`;
    const date = new Date(dateStringWithTime);
    return [_formatDate(date)];
  } catch (err) {
    return [];
  }
}

export function getFeatureIcons(hit, type) {
  const alertFeature = _getAlertIcon(hit, type);
  switch (type) {
    case "popular":
    case "stops":
      return _stopIcons(hit, type);

    case "routes":
      return _featuresToIcons(alertFeature);

    case "projects":
      return projectsDate(hit);

    case "pages":
    case "documents":
      return pagesdocumentsDate(hit);
    case "events":
    case "news":
      return _contentDate(hit);

    default:
      return [];
  }
}

export function parseResult(hit, index) {
  return Object.assign(hit, {
    hitIcon: getIcon(hit, index),
    hitUrl: getUrl(hit, index),
    hitTitle: getTitle(hit, index),
    hasDate:
      index === "events" ||
      index === "news" ||
      index === "pages" ||
      index === "documents" ||
      index === "projects" ||
      null,
    hitFeatureIcons: getFeatureIcons(hit, index),
    id: hit.place_id || null
  });
}

export function renderResult(hit, index) {
  if (hit._content_type == "project" || hit._content_type == "project_update") {
    return TEMPLATES.projects.render(parseResult(hit, "projects"));
  }
  if (TEMPLATES[index]) {
    return TEMPLATES[index].render(parseResult(hit, index));
  }
  return TEMPLATES.default.render(parseResult(hit, index));
}
