/* eslint-disable @next/next/no-img-element */
/** Moldura de celular; `top` é a cor da barra de status (igual ao topo da tela). */
export function PhoneFrame({ src, alt, top = "#E5267A", className = "" }: { src: string; alt: string; top?: string; className?: string }) {
  return (
    <div className={`relative rounded-[2.6rem] bg-[#0E0A18] p-2 shadow-2xl ring-1 ring-white/10 ${className}`}>
      <div className="overflow-hidden rounded-[2.1rem]" style={{ background: top }}>
        <div className="relative h-7">
          <div className="absolute left-1/2 top-1.5 h-4 w-16 -translate-x-1/2 rounded-full bg-black" />
        </div>
        <img src={src} alt={alt} className="block w-full" loading="lazy" />
      </div>
    </div>
  );
}
