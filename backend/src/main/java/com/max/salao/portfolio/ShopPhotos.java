package com.max.salao.portfolio;

import java.io.IOException;
import java.util.UUID;

import com.max.salao.shared.BusinessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

/** Foto de produto da loja do representante: mesma compressão e armazenamento (R2 ou disco) do portfólio. */
@Component
public class ShopPhotos {

    private static final Logger log = LoggerFactory.getLogger(ShopPhotos.class);

    public record Stored(String imageUrl, String thumbUrl) {
    }

    private final ImageProcessor images;
    private final MediaStorage storage;
    private final MediaProperties props;

    ShopPhotos(ImageProcessor images, MediaStorage storage, MediaProperties props) {
        this.images = images;
        this.storage = storage;
        this.props = props;
    }

    public Stored store(MultipartFile file, long representativeId) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Escolha uma foto");
        }
        if (file.getSize() > props.maxUploadMb() * 1024L * 1024L) {
            throw new BusinessException("Foto grande demais (máximo " + props.maxUploadMb() + " MB)");
        }
        byte[] data;
        try {
            data = file.getBytes();
        } catch (IOException e) {
            throw new BusinessException("Não foi possível ler o arquivo enviado");
        }
        ImageProcessor.Processed img = images.process(data);
        String base = "shop/" + representativeId + "/" + UUID.randomUUID().toString().replace("-", "");
        String imageKey = base + ".jpg", thumbKey = base + "_t.jpg";
        try {
            return new Stored(storage.put(imageKey, img.image(), "image/jpeg"), storage.put(thumbKey, img.thumb(), "image/jpeg"));
        } catch (RuntimeException e) {
            log.error("Falha ao gravar foto da loja", e);
            storage.delete(imageKey);
            throw new BusinessException("Não foi possível guardar a foto agora. Tente de novo.");
        }
    }
}
