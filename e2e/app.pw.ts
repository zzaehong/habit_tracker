import { test, expect } from "@playwright/test";
import { Repository } from "../server/store";
import { pairingCode } from "../server/app";
import { readFileSync } from "node:fs";
async function ready(page: any) {
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "오늘도, 차곡차곡." }),
  ).toBeVisible();
  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
  });
}
test("러닝 입력, 오프라인 재실행, 백업 내보내기", async ({ page, context }) => {
  await ready(page);
  await page.screenshot({ path: "runtime/desktop.png", fullPage: true });
  const card = page
    .locator(".card")
    .filter({ has: page.getByRole("heading", { name: "러닝", exact: true }) });
  await card.getByRole("button", { name: "＋ 상세 기록" }).click();
  const dialog = page.getByRole("dialog", { name: "러닝 기록" });
  await dialog.getByLabel("거리 (km)", { exact: true }).fill("5");
  await dialog.getByLabel("시간 (분:초)", { exact: true }).fill("32:00");
  await dialog.getByLabel("평균 심박수 (bpm)", { exact: true }).fill("145");
  await dialog
    .getByRole("button", { name: "기기에 저장", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await expect(card).toContainText("5 km");
  await context.setOffline(true);
  await page.reload();
  await expect(card).toContainText("5 km");
  await card.getByRole("button", { name: "기록 수정" }).click();
  await page.getByLabel("메모", { exact: true }).fill("오프라인 메모");
  await page.getByRole("button", { name: "기기에 저장", exact: true }).click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await page.reload();
  await page.getByRole("button", { name: "기록", exact: true }).click();
  await expect(page.getByText("오프라인 메모", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "설정", exact: true }).first().click();
  const download = page.waitForEvent("download");
  await page.getByRole("button", { name: "JSON 내보내기" }).click();
  const file = await (await download).path();
  const data = JSON.parse(readFileSync(file!, "utf8"));
  expect(
    data.entities.some(
      (e: any) =>
        e.type === "entry" &&
        e.data.distance === 5 &&
        e.data.note === "오프라인 메모",
    ),
  ).toBe(true);
});
test("식단 변경이 지난 식사의 영양소를 바꾸지 않음", async ({ page }) => {
  await ready(page);
  await page.getByRole("button", { name: "설정", exact: true }).first().click();
  const breakfast = page.locator(".settingsrow").filter({ hasText: "아침" });
  await breakfast.getByRole("button", { name: "식단 설정" }).click();
  const plan = page.getByRole("dialog", { name: "식단 설정" });
  await plan.getByLabel("메뉴", { exact: true }).fill("오트밀과 달걀");
  await plan.getByLabel("열량 (kcal)").fill("400");
  await plan.getByLabel("탄수화물 (g)").fill("50");
  await plan.getByLabel("단백질 (g)").fill("25");
  await plan.getByLabel("지방 (g)").fill("11");
  await plan.getByRole("button", { name: "식단 저장" }).click();
  await page.getByRole("button", { name: "오늘", exact: true }).click();
  await page.getByRole("button", { name: "식단대로", exact: true }).click();
  await expect(page.getByRole("button", { name: "식사 수정" })).toBeVisible();
  await page.getByRole("button", { name: "설정", exact: true }).first().click();
  await breakfast.getByRole("button", { name: "식단 설정" }).click();
  await page.getByLabel("열량 (kcal)").fill("700");
  await page.getByRole("button", { name: "식단 저장" }).click();
  await page.getByRole("button", { name: "오늘", exact: true }).click();
  await page.getByRole("button", { name: "식사 수정" }).click();
  await expect(page.getByLabel("열량 (kcal)")).toHaveValue("400");
});
test("모바일 입력, 사용자 정의 항목, 자연어 원문 오프라인 보존", async ({
  page,
  context,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await ready(page);
  await page.screenshot({ path: "runtime/mobile.png", fullPage: true });
  await page.getByRole("button", { name: "설정", exact: true }).first().click();
  const study = page.locator(".settingsrow").filter({ hasText: /^공부/ });
  await study.getByRole("button", { name: "설정", exact: true }).click();
  await page.getByRole("button", { name: "＋ 항목 추가" }).click();
  await page.getByLabel("이름", { exact: true }).fill("집중도");
  await page.getByRole("button", { name: "설정 저장", exact: true }).click();
  await page.getByRole("button", { name: "오늘", exact: true }).click();
  const card = page
    .locator(".card")
    .filter({ has: page.getByRole("heading", { name: "공부", exact: true }) });
  await card.getByRole("button", { name: "＋ 상세 기록" }).click();
  await page.getByLabel("집중도", { exact: true }).fill("4");
  await page.getByRole("button", { name: "기기에 저장", exact: true }).click();
  await context.setOffline(true);
  await page.getByRole("button", { name: /한 문장으로 기록/ }).click();
  await page.getByLabel("자연어 기록").fill("어제 회계 30분 공부했어");
  await page.getByRole("button", { name: "원문 저장 · 정리 요청" }).click();
  await expect(page.getByText("AI 정리 대기", { exact: true })).toBeVisible();
  await page.reload();
  await page.getByRole("button", { name: /한 문장으로 기록/ }).click();
  await expect(
    page.getByText("어제 회계 30분 공부했어", { exact: true }),
  ).toBeVisible();
});
test("인증 후 두 브라우저 간 기록 동기화", async ({ browser }) => {
  const one = await browser.newContext();
  const two = await browser.newContext();
  try {
    const a = await one.newPage(),
      b = await two.newPage();
    for (const p of [a, b]) {
      await ready(p);
      await p
        .getByRole("button", { name: "설정", exact: true })
        .first()
        .click();
      const repo = new Repository(
        process.env.CHAGOK_E2E_DIR + "/chagok.sqlite",
      );
      const code = pairingCode(repo);
      repo.close();
      await p.getByLabel("연결 코드").fill(code);
      await p.getByRole("button", { name: "기기 연결", exact: true }).click();
      await expect(
        p.getByText("연결되었습니다.", { exact: true }),
      ).toBeVisible();
    }
    await a.getByRole("button", { name: "오늘", exact: true }).click();
    const card = a
      .locator(".card")
      .filter({ has: a.getByRole("heading", { name: "러닝", exact: true }) });
    await card.getByRole("button", { name: "＋ 상세 기록" }).click();
    await a.getByLabel("거리 (km)", { exact: true }).fill("7");
    await a.getByRole("button", { name: "기기에 저장", exact: true }).click();
    await a.getByRole("button", { name: "설정", exact: true }).first().click();
    await a.getByRole("button", { name: "지금 동기화" }).click();
    await expect(a.locator(".badge")).toContainText(/저장됨|완료/);
    await b.getByRole("button", { name: "지금 동기화" }).click();
    await b.getByRole("button", { name: "기록", exact: true }).click();
    await expect(
      b.getByRole("heading", { name: /7 km/ }).first(),
    ).toBeVisible();
  } finally {
    await one.close();
    await two.close();
  }
});

test("오프라인 캡처와 이미지 포함 ZIP을 새 기기에 복원", async ({
  page,
  context,
  browser,
}) => {
  await ready(page);
  const image = await page.screenshot();
  await context.setOffline(true);
  const card = page
    .locator(".card")
    .filter({ has: page.getByRole("heading", { name: "러닝", exact: true }) });
  await card.getByRole("button", { name: "＋ 상세 기록" }).click();
  await page
    .getByLabel("NRC 캡처 업로드")
    .setInputFiles({
      name: "nrc-fixture.png",
      mimeType: "image/png",
      buffer: image,
    });
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await expect(page.getByRole("img", { name: "러닝 캡처 원본" })).toHaveCount(
    1,
  );
  await page.reload();
  await page.getByRole("button", { name: /한 문장으로 기록/ }).click();
  await expect(page.getByRole("img", { name: "러닝 캡처 원본" })).toHaveCount(
    1,
  );
  await page.getByRole("button", { name: "설정", exact: true }).first().click();
  const event = page.waitForEvent("download");
  await page
    .getByRole("button", { name: "이미지 포함 ZIP", exact: true })
    .click();
  const file = await (await event).path();
  const restored = await browser.newContext();
  try {
    const p = await restored.newPage();
    await ready(p);
    await p.getByRole("button", { name: "설정", exact: true }).first().click();
    await p.getByLabel("JSON / ZIP 복원").setInputFiles({name:"backup.zip",mimeType:"application/zip",buffer:readFileSync(file!)});
    await p.getByRole("button", { name: "복원 실행", exact: true }).click();
    await expect(p.getByText(/복원 완료/)).toBeVisible();
    await p.getByRole("button", { name: /한 문장으로 기록/ }).click();
    await expect(p.getByRole("img", { name: "러닝 캡처 원본" })).toHaveCount(1);
  } finally {
    await restored.close();
  }
});
