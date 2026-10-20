package com.max.salao.portfolio;

import java.util.List;

import com.max.salao.portfolio.PortfolioService.PhotoResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Portfólio de fotos: o salão envia, legenda, ordena e apaga; o cliente vê a galeria na página pública. */
@RestController
public class PortfolioController {

    public record PhotoRequest(@Size(max = 200) String caption, Long serviceId, Long professionalId) {
    }

    public record OrderRequest(@NotNull @Size(max = 10000) List<Long> ids) {
    }

    private final PortfolioService service;

    public PortfolioController(PortfolioService service) {
        this.service = service;
    }

    @GetMapping("/api/portfolio")
    public List<PhotoResponse> list(@RequestParam(required = false) Long serviceId) {
        return service.list(serviceId);
    }

    @PostMapping(value = "/api/portfolio", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public PhotoResponse upload(@RequestPart("file") MultipartFile file,
                                @RequestParam(required = false) String caption,
                                @RequestParam(required = false) Long serviceId,
                                @RequestParam(required = false) Long professionalId) {
        return service.upload(file, caption, serviceId, professionalId);
    }

    @PutMapping("/api/portfolio/{id}")
    public PhotoResponse update(@PathVariable Long id, @Valid @RequestBody PhotoRequest req) {
        return service.update(id, req.caption(), req.serviceId(), req.professionalId());
    }

    @PutMapping("/api/portfolio/order")
    public List<PhotoResponse> reorder(@Valid @RequestBody OrderRequest req) {
        return service.reorder(req.ids());
    }

    @DeleteMapping("/api/portfolio/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        service.delete(id);
    }

    /** Galeria pública do salão (ou de um serviço). */
    @GetMapping("/api/public/salons/{slug}/portfolio")
    public List<PhotoResponse> publicList(@PathVariable String slug, @RequestParam(required = false) Long serviceId) {
        return service.listPublic(serviceId);
    }
}
