import React, { ReactElement, useState } from "react";
import { handleReactEnterKeyPress } from "../helpers/keyboard-events";
import renderSvg from "../helpers/render-svg";
import { caret } from "../helpers/icon";

export interface ExpandableBlockHeader {
  text: string | ReactElement<HTMLElement>;
  iconSvgText: string | null;
}

// If dispatch is provided in Props, the block will not
// track its own state -- the parent is fully responsible
// for tracking the expanded/collapsed state.
// If dispatch is not provided, the block will
// track its own state.
interface Props {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  dispatch?: React.Dispatch<any>;
  initiallyExpanded: boolean;
  initiallyFocused?: boolean;
  header: ExpandableBlockHeader;
  children: ReactElement<HTMLElement>;
  id: string;
}

interface State {
  expanded: boolean;
  focused?: boolean;
}

export interface ClickExpandableBlockAction {
  type: "CLICK_EXPANDABLE_BLOCK";
  payload: {
    expanded: boolean;
    focused: boolean;
    id: string;
  };
}

const ExpandableBlock = (props: Props): ReactElement<HTMLElement> => {
  const {
    header: { text, iconSvgText },
    dispatch,
    initiallyExpanded,
    initiallyFocused,
    children,
    id
  } = props;

  const initialState = {
    expanded: initiallyExpanded,
    focused: initiallyFocused
  };

  const action: ClickExpandableBlockAction = {
    type: "CLICK_EXPANDABLE_BLOCK",
    payload: {
      expanded: initiallyExpanded === true,
      focused: initiallyFocused === true,
      id
    }
  };

  const [hookedState, toggleExpanded] = useState(initialState);
  const { state, onClick } = dispatch
    ? {
        state: initialState,
        onClick: () => dispatch(action)
      }
    : {
        state: hookedState,
        onClick: () =>
          toggleExpanded({ expanded: !hookedState.expanded, focused: true })
      };

  const { expanded, focused }: State = state;
  const headerId = `header-${id}`;
  const panelId = `panel-${id}`;

  return (
    <>
      <h3
        className="c-expandable-block__header"
        tabIndex={0}
        id={headerId}
        aria-expanded={expanded}
        aria-controls={panelId}
        // eslint-disable-next-line jsx-a11y/no-noninteractive-element-to-interactive-role
        role="button"
        onClick={onClick}
        onKeyPress={e => handleReactEnterKeyPress(e, onClick)}
      >
        {iconSvgText
          ? renderSvg("c-expandable-block__header-icon", iconSvgText)
          : null}
        <div className="c-expandable-block__header-text">
          {text}
          {caret("c-expandable-block__header-caret", expanded)}
        </div>
      </h3>
      {expanded ? (
        <div
          className="c-expandable-block__panel"
          // eslint-disable-next-line jsx-a11y/no-noninteractive-tabindex
          tabIndex={0}
          role="region"
          id={panelId}
          aria-labelledby={headerId}
          ref={panel => panel && focused && panel.focus()}
        >
          {children}
        </div>
      ) : null}
      {/* No javascript support */}
      <noscript>
        <style>{`#${headerId} { display: none; }`}</style>
        <h3 className="c-expandable-block__header">
          {iconSvgText
            ? renderSvg("c-expandable-block__header-icon", iconSvgText)
            : null}
          {text}
          {caret("c-expandable-block__header-caret", true)}
        </h3>
        <div className="c-expandable-block__panel" role="region">
          {children}
        </div>
      </noscript>
    </>
  );
};

export default ExpandableBlock;
