/* eslint-disable @next/next/no-img-element */
/** Moldura de celular; `top` é a cor da barra de status (igual ao topo da tela). */
export function PhoneFrame({
  src,
  alt,
  top = "#E5267A",
  className = "",
  eager = false,
}: {
  src: string;
  alt: string;
  top?: string;
  className?: string;
  /** true para imagens do topo da página (carregam já, sem lazy). */
  eager?: boolean;
}) {
  return (
    <div className={`relative rounded-[2.6rem] bg-[#0E0A18] p-2 shadow-2xl ring-1 ring-white/10 ${className}`}>
      <div className="overflow-hidden rounded-[2.1rem]" style={{ background: top }}>
        <div className="relative h-7">
          <div className="absolute left-1/2 top-1.5 h-4 w-16 -translate-x-1/2 rounded-full bg-black" />
        </div>
        {/* width/height reservam a proporção da tela mesmo antes (ou se falhar) o carregamento */}
        <img src={src} alt={alt} width={600} height={1223} className="block aspect-[600/1223] h-auto w-full bg-[#FFF7FA] object-cover object-top" loading={eager ? "eager" : "lazy"} />
      </div>
    </div>
  );
}
