package com.max.salao.portfolio;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.max.salao.catalog.ServiceItem;
import com.max.salao.catalog.ServiceItemRepository;
import com.max.salao.plan.PlanService;
import com.max.salao.professional.Professional;
import com.max.salao.professional.ProfessionalRepository;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import com.max.salao.shared.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class PortfolioService {

    private static final Logger log = LoggerFactory.getLogger(PortfolioService.class);

    public record PhotoResponse(Long id, String url, String thumbUrl, String caption, int width, int height,
                                Long serviceId, String serviceName, Long professionalId, String professionalName,
                                LocalDateTime createdAt, Long productId) {

        static PhotoResponse from(PortfolioPhoto p) {
            ServiceItem s = p.getService();
            Professional pro = p.getProfessional();
            return new PhotoResponse(p.getId(), p.getImageUrl(), p.getThumbUrl(), p.getCaption(), p.getWidth(),
                    p.getHeight(), s != null ? s.getId() : null, s != null ? s.getName() : null,
                    pro != null ? pro.getId() : null, pro != null ? pro.getName() : null, p.getCreatedAt(),
                    p.getProduct() != null ? p.getProduct().getId() : null);
        }
    }

    private final PortfolioPhotoRepository photos;
    private final ServiceItemRepository services;
    private final ProfessionalRepository professionals;
    private final ImageProcessor images;
    private final MediaStorage storage;
    private final MediaProperties props;
    private final PlanService plans;
    private final com.max.salao.product.ProductService products;

    public PortfolioService(PortfolioPhotoRepository photos, ServiceItemRepository services,
                            ProfessionalRepository professionals, ImageProcessor images, MediaStorage storage,
                            MediaProperties props, PlanService plans, com.max.salao.product.ProductService products) {
        this.products = products;
        this.photos = photos;
        this.services = services;
        this.professionals = professionals;
        this.images = images;
        this.storage = storage;
        this.props = props;
        this.plans = plans;
    }

    @Transactional(readOnly = true)
    public List<PhotoResponse> list(Long serviceId) {
        return list(serviceId, null);
    }

    /** Com {@code productId}: fotos desse produto; senão a galeria de trabalhos (ou de um serviço). */
    @Transactional(readOnly = true)
    public List<PhotoResponse> list(Long serviceId, Long productId) {
        List<PortfolioPhoto> list = productId != null ? photos.findByProductIdOrderByPositionAscIdDesc(productId)
                : serviceId == null ? photos.findByProductIsNullOrderByPositionAscIdDesc()
                : photos.findByServiceIdOrderByPositionAscIdDesc(serviceId);
        return list.stream().map(PhotoResponse::from).toList();
    }

    /** Página pública: só fotos sem serviço ou de serviço ativo; profissional inativo não aparece pelo nome. */
    @Transactional(readOnly = true)
    public List<PhotoResponse> listPublic(Long serviceId) {
        return (serviceId == null ? photos.findByProductIsNullOrderByPositionAscIdDesc()
                : photos.findByServiceIdOrderByPositionAscIdDesc(serviceId)).stream()
                .filter(p -> p.getService() == null || p.getService().isActive())
                .map(p -> {
                    PhotoResponse r = PhotoResponse.from(p);
                    boolean hidePro = p.getProfessional() != null && !p.getProfessional().isActive();
                    return hidePro ? new PhotoResponse(r.id(), r.url(), r.thumbUrl(), r.caption(), r.width(),
                            r.height(), r.serviceId(), r.serviceName(), null, null, r.createdAt(), null) : r;
                })
                .toList();
    }

    /**
     * Comprime, grava (R2 ou disco) e registra. A imagem é processada fora de transação; a foto
     * nova entra no começo da galeria.
     */
    public PhotoResponse upload(MultipartFile file, String caption, Long serviceId, Long professionalId) {
        return upload(file, caption, serviceId, professionalId, null);
    }

    public PhotoResponse upload(MultipartFile file, String caption, Long serviceId, Long professionalId, Long productId) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Escolha uma foto");
        }
        if (file.getSize() > props.maxUploadMb() * 1024L * 1024L) {
            throw new BusinessException("Foto grande demais (máximo " + props.maxUploadMb() + " MB)");
        }
        plans.checkPhotoLimit();
        ServiceItem service = findService(serviceId);
        Professional professional = findProfessional(professionalId);
        com.max.salao.product.Product product = findProduct(productId);

        byte[] data;
        try {
            data = file.getBytes();
        } catch (IOException e) {
            throw new BusinessException("Não foi possível ler o arquivo enviado");
        }
        ImageProcessor.Processed img = images.process(data);
        data = null;

        String base = "salons/" + TenantContext.get() + "/" + UUID.randomUUID().toString().replace("-", "");
        String imageKey = base + ".jpg", thumbKey = base + "_t.jpg";
        String imageUrl, thumbUrl;
        try {
            imageUrl = storage.put(imageKey, img.image(), "image/jpeg");
            thumbUrl = storage.put(thumbKey, img.thumb(), "image/jpeg");
        } catch (RuntimeException e) {
            log.error("Falha ao gravar foto do portfólio", e);
            storage.delete(imageKey);
            throw new BusinessException("Não foi possível guardar a foto agora. Tente de novo.");
        }

        PortfolioPhoto p = new PortfolioPhoto();
        p.setService(service);
        p.setProfessional(professional);
        p.setProduct(product);
        p.setCaption(clean(caption));
        p.setImageKey(imageKey);
        p.setThumbKey(thumbKey);
        p.setImageUrl(imageUrl);
        p.setThumbUrl(thumbUrl);
        p.setWidth(img.width());
        p.setHeight(img.height());
        p.setSizeBytes(img.image().length + (long) img.thumb().length);
        p.setPosition(photos.minPosition() - 1);
        return PhotoResponse.from(photos.save(p));
    }

    @Transactional
    public PhotoResponse update(Long id, String caption, Long serviceId, Long professionalId) {
        PortfolioPhoto p = find(id);
        p.setCaption(clean(caption));
        p.setService(findService(serviceId));
        p.setProfessional(findProfessional(professionalId));
        return PhotoResponse.from(p);
    }

    /** Nova ordem da galeria: ids na ordem desejada (fotos não listadas vão para o fim). */
    @Transactional
    public List<PhotoResponse> reorder(List<Long> ids) {
        Map<Long, Integer> order = new HashMap<>();
        for (int i = 0; i < ids.size(); i++) {
            order.putIfAbsent(ids.get(i), i);
        }
        List<PortfolioPhoto> all = photos.findByProductIsNullOrderByPositionAscIdDesc();
        int next = ids.size();
        for (PortfolioPhoto p : all) {
            Integer pos = order.get(p.getId());
            p.setPosition(pos != null ? pos : next++);
        }
        return list(null);
    }

    public void delete(Long id) {
        PortfolioPhoto p = find(id);
        photos.delete(p);
        storage.delete(p.getImageKey());
        storage.delete(p.getThumbKey());
    }

    /** Fotos de um serviço (ler antes de excluí-lo, para apagar só depois que a exclusão der certo). */
    public List<PortfolioPhoto> photosOfService(Long serviceId) {
        return photos.findByServiceIdOrderByPositionAscIdDesc(serviceId);
    }

    /** Fotos de um produto (idem). */
    public List<PortfolioPhoto> photosOfProduct(Long productId) {
        return photos.findByProductIdOrderByPositionAscIdDesc(productId);
    }

    /** Remove as fotos do banco (junto com a exclusão do serviço/produto) e devolve os arquivos a apagar depois. */
    public List<String> removeRows(List<PortfolioPhoto> list) {
        List<String> keys = new java.util.ArrayList<>();
        for (PortfolioPhoto p : list) {
            keys.add(p.getImageKey());
            keys.add(p.getThumbKey());
        }
        photos.deleteAll(list);
        return keys;
    }

    /** Apaga os arquivos das fotos (só depois de a exclusão no banco ter dado certo). */
    public void deleteFiles(List<String> keys) {
        keys.stream().filter(java.util.Objects::nonNull).forEach(storage::delete);
    }

    private PortfolioPhoto find(Long id) {
        return photos.findById(id).orElseThrow(() -> new NotFoundException("Foto não encontrada"));
    }

    private ServiceItem findService(Long id) {
        return id == null ? null : services.findById(id).orElseThrow(() -> new NotFoundException("Serviço não encontrado"));
    }

    private com.max.salao.product.Product findProduct(Long id) {
        return id == null ? null : products.find(id);
    }

    private Professional findProfessional(Long id) {
        return id == null ? null
                : professionals.findById(id).orElseThrow(() -> new NotFoundException("Profissional não encontrado"));
    }

    private static String clean(String caption) {
        if (caption == null || caption.isBlank()) {
            return null;
        }
        String c = caption.trim();
        if (c.length() > 200) {
            throw new BusinessException("Legenda com no máximo 200 caracteres");
        }
        return c;
    }
}
