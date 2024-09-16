/* eslint-disable no-underscore-dangle */
import React from "react";
import { get, uniqueId } from "lodash";
import { SourceTemplates, VNode } from "@algolia/autocomplete-js";
import { AutocompleteItem } from "../__autocomplete";
import {
  getTitleAttribute,
  isContentItem,
  isRouteItem,
  isSearchResultItem,
  isStopItem
} from "../helpers";
import {
  contentIcon,
  getFeatureIcons,
  getIcon
} from "../../../../js/algolia-result";

// parse this from a stop's address until we can get it as a stop field
const stateAbbr = (address: string): string =>
  (address.split(",").pop() || "").substring(1, 3);

export function LinkForItem(props: {
  item: AutocompleteItem;
  query: string;
  children: string | VNode | VNode[];
}): React.ReactElement {
  const { item, query, children } = props;

  let url = isContentItem(item) ? item._content_url : item.url;

  // Search result items are a subset of content items that point to a different URL
  if (isSearchResultItem(item)) {
    url = item._search_result_url.replace(/(internal|entity):/g, "/");
  }

  // Strip extra forward slashes as they break relative links
  url = url.replace(/\/\//g, "/");

  // Special case: When the matching text isn't part of the page title, help the
  // user locate the matching text by linking directly to / scrolling to the
  // matching text on the page.
  const highlightedResult = get(item._highlightResult, getTitleAttribute(item));
  if (
    isContentItem(item) &&
    highlightedResult &&
    highlightedResult.matchedWords.length === 0
  ) {
    // link directly to queried text via URL fragment text directive, supported
    // in most browsers, ignored by the others.
    const urlToQuery = `${url}#:~:text=${encodeURIComponent(query)}`;
    return (
      <a href={urlToQuery} className="aa-ItemLink">
        {children}
      </a>
    );
  }

  return (
    <a href={url} className="aa-ItemLink">
      {children}
    </a>
  );
}

const AlgoliaItemTemplate: SourceTemplates<AutocompleteItem>["item"] = ({
  item,
  components
}) => {
  const { index } = item as AutocompleteItem;
  // dev-only hack as that's where we use the *_test Algolia indexes, and the
  // older functions for identifying relevant icons depends on the normal index
  // names.
  const indexName = index.replace("_test", "");
  const attribute = getTitleAttribute(item);
  const featureIcons = getFeatureIcons(item, indexName);
  const iconHtml = isContentItem(item)
    ? contentIcon(item)
    : getIcon(item, indexName);
  return (
    <div className="aa-ItemContent tw-mt-1">
      <div className="tw-flex-grow">
        <div className="tw-flex tw-items-baseline tw-gap-1">
          <span
            className="tw-basis-4 tw-flex-shrink-0"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: iconHtml
            }}
          />
          <div className="aa-ItemContentTitle tw-flex-grow tw-font-normal">
            <span className={isStopItem(item) ? "notranslate" : undefined}>
              {components.Highlight({
                hit: item,
                attribute
              })}
            </span>
            {isStopItem(item) && !item.stop["station?"] && (
              <span className="tw-text-gray-500 tw-text-sm tw-ml-2">
                #{item.stop.id}
              </span>
            )}
            &nbsp;
            {isRouteItem(item) && item.route.type === 3 && (
              <span className="tw-text-nowrap tw-text-gray-500 tw-text-sm tw-font-normal notranslate">
                {components.Highlight({
                  hit: item,
                  attribute: ["route", "long_name"]
                })}
              </span>
            )}
          </div>
        </div>
        {!isContentItem(item) && featureIcons.length > 0 && (
          <div className="tw-flex tw-gap-1 tw-mt-2 tw-mb-1">
            {featureIcons.map((feature: string) => (
              <span
                key={uniqueId()}
                className="c-search-result__feature-icons"
                // eslint-disable-next-line react/no-danger
                dangerouslySetInnerHTML={{ __html: feature }}
              />
            ))}
          </div>
        )}
      </div>

      {isStopItem(item) && (
        <div className="tw-text-nowrap tw-text-gray-500 tw-text-sm tw-font-normal">
          {`${item.stop.municipality}, ${
            item.stop.address ? stateAbbr(item.stop.address) : "MA"
          }`}
        </div>
      )}
    </div>
  );
};

export default AlgoliaItemTemplate;
