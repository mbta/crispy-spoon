import { useEffect, useState } from "react";

const glxStations = ["place-lech", "place-unsqu", "place-spmnl"];

export const getIsGlxOpen = (stationId: string) => {
  const glxOpen = document.querySelector(".glx-is-open");
  console.log(glxOpen)
  if (glxOpen instanceof HTMLElement) {
    return glxOpen.dataset.open === "true" && glxStations.indexOf(stationId) > 0;
  }
  return false;
}

const useGlxOpen = (stationId: string): boolean => {
  const [isGlxOpen, setIsGlxOpen] = useState(false);
  useEffect(() => {
    setIsGlxOpen(getIsGlxOpen(stationId));
  }, []);

  return isGlxOpen;
};

export default useGlxOpen;
