import { createMDX } from "fumadocs-mdx/next";

const sourceRevision = process.env.PACOTINHO_SOURCE_REVISION;
if (sourceRevision && !/^[0-9a-f]{40}$/.test(sourceRevision)) {
  throw new Error("PACOTINHO_SOURCE_REVISION must be a full lowercase Git SHA");
}

const config = {
  reactStrictMode: true,
  output: "standalone",
  generateBuildId: async () => sourceRevision ?? "local-development",
};

const withMDX = createMDX();
export default withMDX(config);
