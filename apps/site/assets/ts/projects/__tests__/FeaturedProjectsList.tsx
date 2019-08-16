import React from "react";
import renderer, { act } from "react-test-renderer";
import { SimpleProject as Project } from "../components/__projects";
import FeaturedProjectsList from "../components/FeaturedProjectsList";
import { createReactRoot } from "../../app/helpers/testUtils";

const projects = [
  {
    date: "2018-05-01",
    id: 1234,
    image: {
      url: "https://www.imagehost.com/pictureofatrain.jpg",
      alt: "Picture of a train. Choo choo!"
    },
    path: "/choo-choo",
    routes: [
      { mode: "bus", id: "123", group: "route" },
      { mode: "commuter_rail", id: "CR-Anyplace", group: "line" }
    ],
    title: "New choo-choos!",
    text: "We bought new trains. Choo choo!",
    status: null
  },
  {
    date: "2018-04-01",
    id: 2345,
    image: {
      url: "https://www.imagehost.com/pictureofworkers.jpg",
      alt: "People fixing track or something"
    },
    path: "/fixing-track",
    routes: [{ mode: "subway", id: "Blue", group: "line" }],
    title: "Track fixing",
    text: "We're fixing the track. It needs it.",
    status: null
  },
  {
    date: "2018-03-01",
    id: 3456,
    image: {
      url: "https://www.imagehost.com/pictureofastation.jpg",
      alt: "Facade of East Station"
    },
    path: "/east-station",
    routes: [{ mode: "subway", id: "Red", group: "line" }],
    title: "East Station opening",
    text: "We opened East Station, even though it's on the harbor floor.",
    status: null
  }
];

const placeholderImageUrl = "https://www.example.com/someimage.png";

it("renders", () => {
  createReactRoot();
  const tree = renderer
    .create(
      <FeaturedProjectsList
        projects={projects}
        placeholderImageUrl={placeholderImageUrl}
      />
    )
    .toJSON();
  expect(tree).toMatchSnapshot();
});
