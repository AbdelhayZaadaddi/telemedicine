package com.emsi.telemedicine.exception;

import com.emsi.telemedicine.dto.ErrorResponse;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;

import java.util.List;

/**
 * Erreurs de Bean Validation (@Valid sur les paramètres des ressources) -> HTTP 400.
 */
@Provider
public class ConstraintViolationExceptionMapper implements ExceptionMapper<ConstraintViolationException> {

    @Override
    public Response toResponse(ConstraintViolationException e) {
        List<String> details = e.getConstraintViolations().stream()
                .map(ConstraintViolationExceptionMapper::format)
                .sorted()
                .toList();
        return Response.status(Response.Status.BAD_REQUEST)
                .type(MediaType.APPLICATION_JSON)
                .entity(new ErrorResponse(400, "Données invalides", details))
                .build();
    }

    private static String format(ConstraintViolation<?> v) {
        // "create.dto.email" -> "email"
        String path = v.getPropertyPath().toString();
        String field = path.substring(path.lastIndexOf('.') + 1);
        return field + " : " + v.getMessage();
    }
}
