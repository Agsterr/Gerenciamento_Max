package com.max.salao.portfolio;

import java.util.List;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface PortfolioPhotoRepository extends JpaRepository<PortfolioPhoto, Long> {

    /** Galeria de trabalhos (sem as fotos de produtos). */
    @EntityGraph(attributePaths = {"service", "professional"})
    List<PortfolioPhoto> findByProductIsNullOrderByPositionAscIdDesc();

    @EntityGraph(attributePaths = {"service", "professional"})
    List<PortfolioPhoto> findByServiceIdOrderByPositionAscIdDesc(Long serviceId);

    List<PortfolioPhoto> findByProductIdOrderByPositionAscIdDesc(Long productId);

    /** Primeira foto de cada produto (para a miniatura da lista). */
    @Query("select p.product.id, p.thumbUrl from PortfolioPhoto p where p.product is not null order by p.position, p.id desc")
    List<Object[]> productThumbs();

    /** (id do produto, miniatura, imagem) das fotos de produtos, a primeira de cada produto vem antes. */
    @Query("select p.product.id, p.thumbUrl, p.imageUrl from PortfolioPhoto p where p.product is not null order by p.position, p.id desc")
    List<Object[]> productPhotoUrls();

    @Query("select coalesce(min(p.position), 0) from PortfolioPhoto p")
    int minPosition();
}
