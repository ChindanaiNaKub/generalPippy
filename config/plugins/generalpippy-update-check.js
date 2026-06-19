import { checkForUpdate, formatUpdateNotice, markPrompted } from "../generalpippy/update-check.mjs";

export const GeneralPippyUpdateCheck = async ({ client }) => {
  let checked = false;

  async function runOnce() {
    if (checked) return;
    checked = true;

    try {
      const result = await checkForUpdate({ startup: true });
      if (result.status !== "update_available" || !result.should_prompt) return;

      markPrompted(result.latest.version);
      const notice = `${formatUpdateNotice(result)}\nRun /pippy-update to update, or set GENERALPIPPY_UPDATE_CHECK=0 to disable checks.`;

      if (client?.app?.log) {
        await client.app.log({
          body: {
            service: "generalpippy-update-check",
            level: "warn",
            message: notice,
          },
        });
      } else {
        console.warn(notice);
      }
    } catch (error) {
      if (client?.app?.log) {
        await client.app.log({
          body: {
            service: "generalpippy-update-check",
            level: "debug",
            message: `GeneralPippy update check skipped: ${error.message}`,
          },
        });
      }
    }
  }

  return {
    event: async ({ event }) => {
      if (event?.type === "server.connected" || event?.type === "session.created") {
        await runOnce();
      }
    },
  };
};
