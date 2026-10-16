import Link from "next/link";

export function LegalPage({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <main className="mx-auto max-w-3xl px-4 py-10">
      <Link href="/" className="text-lg font-bold text-rose-600">
        Salão Max
      </Link>
      <h1 className="mb-6 mt-4 text-3xl font-bold">{title}</h1>
      <div className="space-y-4 leading-relaxed text-zinc-700 [&_h2]:mt-8 [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:text-zinc-900 [&_li]:ml-5 [&_li]:list-disc">
        {children}
      </div>
    </main>
  );
}
