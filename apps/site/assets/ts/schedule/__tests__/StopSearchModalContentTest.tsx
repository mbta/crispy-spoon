import React from "react";
import renderer from "react-test-renderer";
import { mount } from "enzyme";
import StopSearchModalContent from "../components/schedule-finder/StopSearchModalContent";
import { createReactRoot } from "../../app/helpers/testUtils";

const stops = [
  {
    name: "SL",
    id: "741",
    is_closed: false,
    zone: "1"
  },
  {
    name: "Abc",
    id: "123",
    is_closed: false,
    zone: null
  },
  {
    name: "Def",
    id: "456",
    is_closed: false,
    zone: null
  },
  {
    name: "Wellington",
    id: "place-welln",
    is_closed: true,
    zone: null
  }
];

describe("StopSearchModalContent", () => {
  it("renders a modal", () => {
    createReactRoot();
    const tree = renderer
      .create(
        <StopSearchModalContent
          handleChangeStop={() => {}}
          selectedStop={"place-welln"}
          stops={stops}
          searchLabel="Choose an origin stop"
          disabledStop={"place-welln"}
        />
      )
      .toJSON();
    expect(tree).toMatchSnapshot();
  });

  it("allows you to filter the list of stops", () => {
    const wrapper = mount(
      <StopSearchModalContent
        handleChangeStop={() => {}}
        selectedStop={"place-welln"}
        stops={stops}
        searchLabel="Choose an origin stop"
        disabledStop={"place-welln"}
      />
    );

    expect(wrapper.find(".stop-search__stop").length).toEqual(4);

    wrapper
      .find(".stop-search__searchbox #stop-search-filter")
      .last()
      .simulate("change", { target: { value: "s" } });

    expect(wrapper.find(".stop-search__stop").length).toEqual(1);
  });
});
