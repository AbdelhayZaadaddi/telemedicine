package com.emsi.telemedicine.exception;

/** Violation d'une règle métier d'unicité (ex. email déjà utilisé) -> HTTP 409. */
public class ConflictException extends RuntimeException {

    public ConflictException(String message) {
        super(message);
    }
}
