import { uniqueId } from "lodash";
import React from "react";
import { SourceTemplates } from "@algolia/autocomplete-js";
import { PopularItem } from "../__autocomplete";
import { getFeatureIcons, getPopularIcon } from "../../../../js/algolia-result";

const PopularItemTemplate: SourceTemplates<PopularItem>["item"] = ({
  item
}) => {
  const iconHtml = getPopularIcon(item.icon);
  const featureIcons = getFeatureIcons(item, "popular");
  return (
    <a href={item.url} className="aa-ItemLink" data-turbolinks="false">
      <div className="aa-ItemContent">
        <span
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: iconHtml
          }}
        />
        {featureIcons.map((feature: string) => (
          <span
            key={uniqueId()}
            className="c-search-result__feature-icons"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{ __html: feature }}
          />
        ))}
        <span className="aa-ItemContentBody">
          <span className="aa-ItemContentTitle notranslate">{item.name}</span>
        </span>
      </div>
    </a>
  );
};

export default PopularItemTemplate;
