import React, { ReactElement } from "react";
import { SimpleProject as Project } from "./__projects";
import FeaturedProjectsRow from "./FeaturedProjectsRow";

interface Props {
  projects: Project[];
  placeholderImageUrl: string;
}

const doGroupPairwise = (
  projectsToGroup: Project[],
  acc: Project[][]
): Project[][] => {
  if (projectsToGroup.length === 0) {
    return acc;
  }

  const nextPair = projectsToGroup.slice(0, 2);
  const rest = projectsToGroup.slice(2);
  return doGroupPairwise(rest, acc.concat([nextPair]));
};

const groupPairwise = (projectsToGroup: Project[]): Project[][] =>
  doGroupPairwise(projectsToGroup, []);

const FeaturedProjectsList = ({
  projects,
  placeholderImageUrl
}: Props): ReactElement<HTMLElement> => {
  const groupedProjects = groupPairwise(projects);

  return (
    <div className="container">
      <div className="c-featured-project-list">
        <div className="container page-section">
          {groupedProjects.map(projectPair => {
            const secondProjectId = projectPair[1] ? projectPair[1].id : "none";
            const key = `featured-projects-row-${
              projectPair[0].id
            }_${secondProjectId}`;
            return (
              <FeaturedProjectsRow
                key={key}
                placeholderImageUrl={placeholderImageUrl}
                projectPair={projectPair}
              />
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default FeaturedProjectsList;
