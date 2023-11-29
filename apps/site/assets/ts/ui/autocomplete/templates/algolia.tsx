/* eslint-disable no-underscore-dangle */
import React from "react";
import { get, uniqueId } from "lodash";
import { SourceTemplates } from "@algolia/autocomplete-js";
import { AutocompleteItem, Item } from "../__autocomplete";
import {
  getTitleAttribute,
  isContentItem,
  isRouteItem,
  isStopItem
} from "../helpers";
import {
  contentIcon,
  getFeatureIcons,
  getIcon
} from "../../../../js/algolia-result";

interface LinkForItemProps {
  item: AutocompleteItem;
  query: string;
  children: React.ReactElement;
}
export function LinkForItem(props: LinkForItemProps): React.ReactElement {
  const { item, query, children } = props;
  const url = isContentItem(item) ? item._content_url : item.url;

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
    // in most browsers, ignored by the others. works with Turbolinks disabled.
    const urlToQuery = `${url}#:~:text=${encodeURIComponent(query)}`;
    return (
      <a href={urlToQuery} className="aa-ItemLink" data-turbolinks="false">
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

const AlgoliaItemTemplate: SourceTemplates<Item>["item"] = ({
  item,
  state,
  components
}) => {
  const { index } = item as AutocompleteItem;
  const attribute = getTitleAttribute(item);
  const featureIcons = getFeatureIcons(item, index);
  const iconHtml = isContentItem(item)
    ? contentIcon(item)
    : getIcon(item, index);
  return (
    <LinkForItem item={item as AutocompleteItem} query={state.query}>
      <div className="aa-ItemContent">
        <span
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: iconHtml
          }}
        />
        {!isContentItem(item) &&
          featureIcons.map((feature: string) => (
            <span
              key={uniqueId()}
              className="c-search-result__feature-icons"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{ __html: feature }}
            />
          ))}
        <span className="aa-ItemContentBody">
          <span className="aa-ItemContentTitle">
            <span className={isStopItem(item) ? "notranslate" : undefined}>
              {components.Highlight({
                hit: item,
                attribute
              })}
            </span>
            &nbsp;
            {isRouteItem(item) && item.route.type === 3 && (
              <span className="c-search-result__long-name notranslate">
                {components.Highlight({
                  hit: item,
                  attribute: ["route", "long_name"]
                })}
              </span>
            )}
          </span>
        </span>
      </div>
    </LinkForItem>
  );
};

export default AlgoliaItemTemplate;
